module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def github
      handle_auth("GitHub")
    end

    def google_oauth2
      handle_auth("Google")
    end

    def failure
      redirect_to new_user_session_path, alert: "Sign in failed. Please try again."
    end

    private

    def handle_auth(kind)
      @user = User.from_omniauth(request.env["omniauth.auth"])

      if @user.persisted?
        flash[:notice] = "Signed in with #{kind}."
        sign_in_and_redirect @user, event: :authentication
      else
        redirect_to new_user_session_path, alert: @user.errors.full_messages.to_sentence
      end
    end
  end
end
