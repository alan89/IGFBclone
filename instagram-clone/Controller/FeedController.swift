//
//  FeedController.swift
//  instagram-clone
//
//  Created by ealan on 17/03/21.
//

import UIKit
import Firebase


class FeedController: UICollectionViewController {
    //MARK: - Properties
    private let reuseIdentifier = "Cell"
    private var  posts = [Post]() {
        didSet { collectionView.reloadData()}
    }
    var post: Post? {
        didSet { collectionView.reloadData() }
    }
    let refresher = UIRefreshControl()
    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        fetchPosts()
        
        if post != nil {
            checkIfUserLikedPosts()
        }
    }
    
    //MARK: - helpers
    func configureUI() {
        navigationItem.title = "Feed"
        collectionView.backgroundColor = .white
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        if post == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(handleLogout))
        }
        refresher.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refresher
    }
    
    //MARK: - ACTIONS
    
    @objc func handleLogout() {
        do{
           try Auth.auth().signOut()
            let controller = LoginController()
            controller.delegate = self.tabBarController as? MainTabController
            let nav = UINavigationController(rootViewController: controller)
            nav.modalPresentationStyle = .fullScreen
            self.present(nav, animated: true, completion: nil)
        }
        catch{
                print("DEBUG : failed to sign out")
        }
    }
    
    @objc func handleRefresh() {
        posts.removeAll()
        fetchPosts()
        refresher.endRefreshing()
    }
    
    //MARK: - API
    func fetchPosts() {
        PostService.fetchFeedPosts { posts in
            self.posts = posts
            self.checkIfUserLikedPosts()
        }
    }
   
    func checkIfUserLikedPosts() {
        if let post = post {
            PostService.checkIfUserLikedPost(post: post) { didlike  in
                self.post?.didLike = didlike
            }
        }else {
            self.posts.forEach { post in
                PostService.checkIfUserLikedPost(post: post) { didLike in
                    if let index = self.posts.firstIndex(where: { $0.postId == post.postId} ) {
                        self.posts[index].didLike = didLike
                    }
                }
            }
        }
    }
}

//MARK: - UICollectionViewDataSource
extension FeedController {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return post == nil ? posts.count : 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FeedCell
        cell.delegate = self
        if let post = post {
            cell.viewModel = PostViewModel(post: post)
        } else {
            cell.viewModel = PostViewModel(post: posts[indexPath.row])
        }
        return cell
    }
}

//MARK: - UICollectionViewDelegateFlowLayout
extension FeedController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let width = view.frame.width
        var height = width + 8 + 40 + 8
        height += 110
        
        return CGSize(width: width, height: height)
    }
}

extension FeedController: FeedCellDelegate {
    func cell(_ cell: FeedCell, wantsToShowUserProfile uid: String) {
        UserService.fetchUser(withUid: uid) { user in
            let controller = ProfileController(user: user)
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
    func cell(_ cell: FeedCell, wantsToShowCommentFor post: Post) {
        let controller = CommentController(post: post)
        navigationController?.pushViewController(controller, animated: true)
    }
    
    func cell(_ cell: FeedCell, didLike post: Post) {
        guard let tab = tabBarController as? MainTabController else { return }
        guard let user = tab.user else { return }
        cell.viewModel?.post.didLike.toggle()
        if post.didLike {
            PostService.unlikePost(post: post) { Error in
                cell.likeButton.setImage(#imageLiteral(resourceName: "like_unselected"), for: .normal)
                cell.likeButton.tintColor = .black
                cell.viewModel?.post.likes = post.likes - 1
            }
        }else {
            PostService.likePOst(post: post) { error in
                cell.likeButton.setImage(#imageLiteral(resourceName: "like_selected"), for: .normal)
                cell.likeButton.tintColor = .red
                cell.viewModel?.post.likes = post.likes + 1
                NotificationService.uploadNotification(toUid: post.ownerUid, fromUser: user, type: .like, post: post)
            }
        }
    }
    
    
}
