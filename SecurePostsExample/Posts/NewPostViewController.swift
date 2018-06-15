//
//  Copyright (c) 2015 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import Firebase
import FirebaseDatabase
import FirebaseAuth
import FirebaseUI

@objc(NewPostViewController)
class NewPostViewController: UIViewController, UITextFieldDelegate {

  var ref: DatabaseReference!
  
  var encryptionEngine = EncryptionEngine.sharedInstance
  
  @IBOutlet weak var bodyTextView: UITextView!
  @IBOutlet weak var titleTextField: UITextField!

  // UIView lifecycle methods
  override func viewDidLoad() {
    super.viewDidLoad()

    // [START create_database_reference]
    self.ref = Database.database().reference()
    // [END create_database_reference]

    let doneBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
    doneBar.isTranslucent = false
    doneBar.barTintColor = UIColor.purple
    doneBar.autoresizingMask = .flexibleWidth
    let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    let done = UIBarButtonItem(title: "Post", style: .plain, target: self, action: #selector(didTapPost))
    done.tintColor = UIColor.yellow
    doneBar.items  = [flex, done, flex]
    doneBar.sizeToFit()
    
    bodyTextView.inputAccessoryView = doneBar
    titleTextField.inputAccessoryView = doneBar
  }

  @IBAction func didTapPost(_ sender: AnyObject) {
    // [START single_value_read]
    let userID = Auth.auth().currentUser?.uid
    ref.child("users").child(userID!).observeSingleEvent(of: .value, with: { (snapshot) in
      // Get user value
      let value = snapshot.value as? NSDictionary
      let username = value?["username"] as? String ?? ""
      let user = AppUser(username: username)

      // ENCRYPT POST BODY:
      var postBody = self.bodyTextView.text!
      
      do {
        postBody = try self.encryptionEngine.encryptOwnPost(body: postBody)
      } catch {
        // encryption error, post as is
      }
      
      // [START_EXCLUDE]
      // Write new post
      self.writeNewPost(withUserID: userID!, username: user.username, title: self.titleTextField.text!, body: postBody)
      // Finish this Activity, back to the stream
      _ = self.navigationController?.popViewController(animated: true)
      // [END_EXCLUDE]
      }) { (error) in
        print(error.localizedDescription)
    }
    // [END single_value_read]
  }

  func writeNewPost(withUserID userID: String, username: String, title: String, body: String) {
    // Create new post at /user-posts/$userid/$postid and at
    // /posts/$postid simultaneously
    // [START write_fan_out]
    let key = ref.child("posts").childByAutoId().key
    let post = ["uid": userID,
                "author": username,
                "title": title,
                "body": body,
                "starCount" : "0"] as [String : Any]
    let childUpdates = ["/posts/\(key)": post,
                        "/user-posts/\(userID)/\(key)/": post]
    ref.updateChildValues(childUpdates)
    // [END write_fan_out]
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return false
  }
}