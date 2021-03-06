require 'test_helper'

describe WorksController do
  let (:delete_all) {
    Work.all.each do |work|
      work.destroy
    end
  }

  let (:work_data) {
    {
      work: {
        title: "new test work",
        category: "album"
      }
    }
  }
  let (:existing_work) {
    works(:poodr)
  }

  describe "Guest Users" do
    describe "root" do
      it "succeeds with all media types" do
        # Precondition: there is at least one media of each category

        get root_path

        must_respond_with :success
      end

      it "succeeds with one media type absent" do
        # Precondition: there is at least one media in two of the categories

        movies = Work.where(category: 'movie')
        movies.each do |movie|
          movie.destroy
        end

        get root_path

        must_respond_with :success
      end

      it "succeeds with no media" do

        delete_all

        get root_path

        must_respond_with :success
      end
    end

    describe "upvote" do

      it "redirects to the work page if no user is logged in" do

        post upvote_path(existing_work.id)


        must_redirect_to root_path
        expect(flash[:status]).must_equal :failure

      end
    end
  end

  CATEGORIES = %w(albums books movies)
  INVALID_CATEGORIES = ["nope", "42", "", "  ", "albumstrailingtext"]

  describe "Logged In Users" do

    describe "index" do
      it "succeeds when there are works" do
        perform_login(users(:dan))

        get works_path

        must_respond_with :success

      end

      it "succeeds when there are no works" do
        perform_login(users(:dan))

        delete_all

        get works_path

        must_respond_with :success
      end
    end

    describe "new" do
      it "succeeds" do
        perform_login(users(:dan))

        get new_work_path

        must_respond_with :success
      end
    end

    describe "create" do
      it "creates a work with valid data for a real category" do
        perform_login(users(:dan))

        CATEGORIES.each do |category|

          work_data[:work][:category] = category
          test_work = Work.new(work_data[:work])
          test_work.must_be :valid?, "Work data was invalid. Please fix."

          expect{
            post works_path, params: work_data
          }.must_change('Work.count', +1)

          must_redirect_to work_path(Work.last)
        end

      end

      it "renders bad_request and does not update the DB for bogus data" do
        perform_login(users(:dan))

        work_data[:work][:title] = nil

        test_work = Work.new(work_data[:work])
        test_work.wont_be :valid?, "Work data wasn't invalid. Please fix."

        expect{
          post works_path, params: work_data
        }.wont_change('Work.count')

        must_respond_with :bad_request
      end

      it "renders 400 bad_request for bogus categories" do
        perform_login(users(:dan))


        INVALID_CATEGORIES.each do |category|
          work_data[:work][:category] = category

          test_work = Work.new(work_data[:work])
          test_work.wont_be :valid?, "Work data wasn't invalid. Please fix."

          expect{
            post works_path, params: work_data
          }.wont_change('Work.count')

          must_respond_with :bad_request
        end
      end

    end

    describe "show" do

      it "succeeds for an extant work ID" do
        perform_login(users(:dan))

        get work_path(existing_work.id)

        must_respond_with :success
      end

      it "renders 404 not_found for a bogus work ID" do
        perform_login(users(:dan))

        existing_work.destroy

        get work_path(existing_work.id)

        must_respond_with :not_found
      end
    end

    describe "edit" do
      it "succeeds for an extant work ID" do
        perform_login(users(:dan))

        get edit_work_path(existing_work.id)

        must_respond_with :success
      end

      it "renders 404 not_found for a bogus work ID" do
        perform_login(users(:dan))

        existing_work.destroy

        get edit_work_path(existing_work.id)

        must_respond_with :not_found
      end
    end

    describe "update" do
      it "succeeds for valid data and an extant work ID" do
        perform_login(users(:dan))

        test_work = Work.new(work_data[:work])
        test_work.must_be :valid?, "Work data was invalid. Please fix."

        expect{
          patch work_path(existing_work.id), params: work_data
        }.wont_change('Work.count')

        existing_work.reload
        (existing_work.title).must_equal test_work.title
        (existing_work.category).must_equal test_work.category

        must_redirect_to work_path(existing_work.id)
      end

      it "renders bad_request for bogus data" do
        perform_login(users(:dan))


        work_data[:work][:title] = existing_work.title
        work_data[:work][:category] = "boooo"
        test_work = Work.new(work_data[:work])
        test_work.wont_be :valid?, "Work data wasn't invalid. Please fix."

        patch work_path(existing_work.id), params: work_data

        must_respond_with :bad_request


      end

      it "renders 404 not_found for a bogus work ID" do
        perform_login(users(:dan))

        existing_work.destroy

        patch work_path(existing_work.id), params: work_data

        must_respond_with :not_found
      end
    end

    describe "destroy" do
      it "succeeds for an extant work ID" do
        perform_login(users(:dan))

        expect{
          delete work_path(existing_work.id)
        }.must_change('Work.count', -1)

        must_respond_with :redirect
        must_redirect_to root_path
      end

      it "renders 404 not_found and does not update the DB for a bogus work ID" do
        perform_login(users(:dan))

        existing_work.destroy

        expect{
          delete work_path(existing_work.id)
        }.wont_change('Work.count')

        must_respond_with :not_found

      end
    end

    describe "upvote" do

      it "succeeds for a logged-in user and a fresh user-vote pair" do
        perform_login(users(:dan))

        expect{
          post upvote_path(existing_work.id)
        }.must_change('Vote.count', +1)

        expect(flash[:status]).must_equal :success
        must_redirect_to work_path(existing_work.id)
      end

      it "redirects to the work page if the user has already voted for that work" do
        perform_login(users(:dan))

        dan = users(:dan)
        vote = Vote.create!(user: dan, work: existing_work)

        expect{
          post upvote_path(existing_work.id)
        }.wont_change('existing_work.votes.length')

        expect(flash[:status]).must_equal :failure
        expect(flash[:result_text]).must_equal "Could not upvote"

      end
    end
  end
end
