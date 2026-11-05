class User < ApplicationRecord
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[github google_oauth2]

    def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid) ||
           find_by(email: auth.info.email, admin: false) ||
           new(email: auth.info.email, password: Devise.friendly_token[0, 20])

    user.assign_attributes(
      provider: auth.provider,
      uid: auth.uid,
      name: auth.info.name,
      avatar_url: auth.info.image
    )
    user.save
    user
  end
end
