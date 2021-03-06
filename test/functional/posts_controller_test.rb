require File.dirname(__FILE__) + '/../test_helper'
require 'posts_controller'

# Re-raise errors caught by the controller.
class PostsController; def rescue_action(e) raise e end; end

class PostsControllerTest < Test::Unit::TestCase
  all_fixtures
  def setup
    @controller = PostsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_create_reply
    counts = lambda { [Post.count, forums(:rails).posts_count, users(:aaron).posts_count, topics(:pdi).posts_count] }
    equal  = lambda { [forums(:rails).topics_count] }
    old_counts = counts.call
    old_equal  = equal.call

    login_as :aaron
    post :create, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :post => { :body => 'blah' }
    assert_redirected_to topic_path(:forum_id => forums(:rails).id, :id => topics(:pdi).id, :anchor => assigns(:post).dom_id, :page => '1')
    assert_equal topics(:pdi), assigns(:topic)
    [forums(:rails), users(:aaron), topics(:pdi)].each &:reload
  
    assert_equal old_counts.collect { |n| n + 1}, counts.call
    assert_equal old_equal, equal.call
  end

  def test_should_update_topic_replied_at_upon_replying
    old=topics(:pdi).replied_at
    login_as :aaron
    post :create, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :post => { :body => 'blah' }
    assert_not_equal(old, topics(:pdi).reload.replied_at)
    assert old < topics(:pdi).reload.replied_at
  end

  def test_should_reply_with_no_body
    assert_difference Post, :count, 0 do
      login_as :aaron
      post :create, :forum_id => forums(:rails).id, :topic_id => posts(:pdi).id, :post => {}
      assert_redirected_to topic_path(:forum_id => forums(:rails).id, :id => posts(:pdi).id, :anchor => 'reply-form', :page => '1')
    end
  end

  def test_should_delete_reply
    counts = lambda { [Post.count, forums(:rails).posts_count, users(:sam).posts_count, topics(:pdi).posts_count] }
    equal  = lambda { [forums(:rails).topics_count] }
    old_counts = counts.call
    old_equal  = equal.call

    login_as :aaron
    delete :destroy, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :id => posts(:pdi_reply).id
    [forums(:rails), users(:sam), topics(:pdi)].each &:reload

    assert_equal old_counts.collect { |n| n - 1}, counts.call
    assert_equal old_equal, equal.call
  end

  def test_should_delete_reply_as_moderator
    assert_difference Post, :count, -1 do
      login_as :sam
      delete :destroy, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :id => posts(:pdi_rebuttal).id
    end
  end

  def test_can_edit_own_post
    login_as :sam
    put :update, :forum_id => forums(:comics).id, :topic_id => topics(:galactus).id, :id => posts(:silver_surfer).id, :post => {}
    assert_redirected_to topic_path(:forum_id => forums(:comics), :id => topics(:galactus), :anchor => posts(:silver_surfer).dom_id, :page => '1')
  end

  def test_can_edit_other_post_as_moderator
    login_as :sam
    put :update, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :id => posts(:pdi_rebuttal).id, :post => {}
    assert_redirected_to topic_path(:forum_id => forums(:rails), :id => posts(:pdi), :anchor => posts(:pdi_rebuttal).dom_id, :page => '1')
  end

  def test_cannot_edit_other_post
    login_as :sam
    put :update, :forum_id => forums(:comics).id, :topic_id => topics(:galactus).id, :id => posts(:galactus).id, :post => {}
    assert_redirected_to login_path
  end

  def test_cannot_edit_own_post_user_id
    login_as :sam
    put :update, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :id => posts(:pdi_reply).id, :post => { :user_id => 32 }
    assert_redirected_to topic_path(:forum_id => forums(:rails), :id => posts(:pdi), :anchor => posts(:pdi_reply).dom_id, :page => '1')
    assert_equal users(:sam).id, posts(:pdi_reply).reload.user_id
  end

  def test_can_edit_other_post_as_admin
    login_as :aaron
    put :update, :forum_id => forums(:rails).id, :topic_id => topics(:pdi).id, :id => posts(:pdi_rebuttal).id, :post => {}
    assert_redirected_to topic_path(:forum_id => forums(:rails), :id => posts(:pdi), :anchor => posts(:pdi_rebuttal).dom_id, :page => '1')
  end
  
  def test_should_view_recent_posts
    get :index
    assert_response :success
    assert_models_equal [posts(:shield_reply), posts(:shield), posts(:silver_surfer), posts(:galactus), posts(:ponies), posts(:pdi_rebuttal), posts(:pdi_reply), posts(:pdi), posts(:sticky)], assigns(:posts)
  end

  def test_should_view_posts_by_forum
    get :index, :forum_id => forums(:comics).id
    assert_response :success
    assert_models_equal [posts(:shield_reply), posts(:shield), posts(:silver_surfer), posts(:galactus)], assigns(:posts)
  end

  def test_should_view_posts_by_user
    get :index, :user_id => users(:sam).id
    assert_response :success
    assert_models_equal [posts(:shield), posts(:silver_surfer), posts(:ponies), posts(:pdi_reply), posts(:sticky)], assigns(:posts)
  end

  def test_should_search_recent_posts
    get :index, :q => 'pdi'
    assert_response :success
    assert_models_equal [posts(:pdi_rebuttal), posts(:pdi_reply), posts(:pdi)], assigns(:posts)
  end

  def test_should_search_posts_by_forum
    get :index, :forum_id => forums(:comics).id, :q => 'galactus'
    assert_response :success
    assert_models_equal [posts(:silver_surfer), posts(:galactus)], assigns(:posts)
  end

  def test_should_search_posts_by_user
    get :index, :user_id => users(:sam).id, :q => 'pdi'
    assert_response :success
    assert_models_equal [posts(:pdi_reply)], assigns(:posts)
  end
  
  def test_should_view_recent_posts_as_rss
    get :index, :format => 'rss'
    assert_response :success
    assert_models_equal [posts(:shield_reply), posts(:shield), posts(:silver_surfer), posts(:galactus), posts(:ponies), posts(:pdi_rebuttal), posts(:pdi_reply), posts(:pdi), posts(:sticky)], assigns(:posts)
  end

  def test_should_view_posts_by_forum_as_rss
    get :index, :forum_id => forums(:comics).id, :format => 'rss'
    assert_response :success
    assert_models_equal [posts(:shield_reply), posts(:shield), posts(:silver_surfer), posts(:galactus)], assigns(:posts)
  end

  def test_should_view_posts_by_user_as_rss
    get :index, :user_id => users(:sam).id, :format => 'rss'
    assert_response :success
    assert_models_equal [posts(:shield), posts(:silver_surfer), posts(:ponies), posts(:pdi_reply), posts(:sticky)], assigns(:posts)
  end
end
