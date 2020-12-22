require 'dry/monads'

# your endpoint using sinatra for example
post '/users' do
  result = UpdateUser.new(User, config.mailer).call(params).to_result
  success_fnc = ->(obj) { obj.to_json }
  err_func = ->(msg) { { error: msg }.to_json }

  result.either(success_fnc, err_func)
end

class UpdateUser
  include Dry::Monads[:result, :try]

  attr_reader :user_model, :mailer

  def initialize(user_model, mailer)
    @user_model = user_model
    @mailer = mailer
  end

  def call(fields)
    fields = yield validate_fields(fields)
    yield validate_email(fields['email'])
    user = yield find_user(fields['id'])
    user = yield update_user(user, { name: fields['name'], email: fields['email'] })
    yield send_email(user, :profile_updated)

    Success(user)
  end

  private

  # Validations, updating user & sending email all of these methods in same class for simplicity

  def validate_fields(fields)
    if fields['email'] && fields['password']
      Success(fields)
    else
      Failure(:missing_fields)
    end
  end

  def validate_email(email)
    if email =~ URI::MailTo::EMAIL_REGEXP
      Success(email)
    else
      Failure(:invalid_email)
    end
  end

  def find_user(id)
    user = user_model.find_by(id: id)

    if user
      Success(user)
    else
      Failure(:user_not_found)
    end
  end

  def update_user(user, data)
    if user.update(data)
      Success(user)
    else
      Failure(:user_update_failed)
    end
  end

  def send_email(email, reason)
    # Try is useful for wrapping code that can raise exception
    Try { mailer.deliver!(email, template: reason) }
  end
end
