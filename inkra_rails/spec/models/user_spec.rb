require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:password).is_at_least(6) }

    it 'validates email format' do
      user.email = 'invalid_email'
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    it 'accepts valid email formats' do
      valid_emails = ['test@example.com', 'user.name@domain.co.uk', 'test+tag@example.org']
      valid_emails.each do |email|
        user.email = email
        expect(user).to be_valid
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:projects).dependent(:destroy) }
    it { is_expected.to have_many(:trackers).dependent(:destroy) }
    it { is_expected.to have_many(:log_entries).dependent(:destroy) }
  end

  describe 'database columns' do
    it { is_expected.to have_db_column(:email).of_type(:string) }
    it { is_expected.to have_db_column(:password_digest).of_type(:string) }
    it { is_expected.to have_db_column(:admin).of_type(:boolean) }
    it { is_expected.to have_db_column(:interests) }
  end

  describe 'password encryption' do
    it 'encrypts password using bcrypt' do
      user = create(:user, password: 'test123')
      expect(user.password_digest).not_to eq('test123')
      expect(user.authenticate('test123')).to eq(user)
    end

    it 'does not authenticate with wrong password' do
      user = create(:user, password: 'test123')
      expect(user.authenticate('wrong')).to be_falsey
    end
  end

  describe '#admin?' do
    context 'when user is not admin' do
      let(:user) { build(:user, admin: false) }

      it 'returns false' do
        expect(user.admin?).to be false
      end
    end

    context 'when user is admin' do
      let(:user) { build(:user, admin: true) }

      it 'returns true' do
        expect(user.admin?).to be true
      end
    end

    context 'when admin is false' do
      let(:user) { create(:user, admin: false) }

      it 'returns false' do
        expect(user.admin?).to be false
      end
    end
  end

  describe 'factory' do
    it 'creates a valid user' do
      expect(build(:user)).to be_valid
    end

    it 'creates an admin user with trait' do
      admin_user = build(:user, :admin)
      expect(admin_user.admin).to be true
    end

    it 'creates a user with interests using trait' do
      user_with_interests = build(:user, :with_interests)
      expect(user_with_interests.interests).to include('fiction_writing', 'personal_growth')
    end
  end

  describe 'interests validation' do
    it 'accepts valid interest categories' do
      valid_interests = %w[fiction_writing non_fiction_writing personal_growth mental_health social_sharing health_fitness]
      user = build(:user, interests: valid_interests)
      expect(user).to be_valid
    end

    it 'rejects invalid interest categories' do
      user = build(:user, interests: ['invalid_category'])
      expect(user).not_to be_valid
      expect(user.errors[:interests]).to include('contains an invalid category')
    end

    it 'accepts empty interests array' do
      user = build(:user, interests: [])
      expect(user).to be_valid
    end

    it 'rejects mixed valid and invalid categories' do
      user = build(:user, interests: ['fiction_writing', 'invalid_category'])
      expect(user).not_to be_valid
      expect(user.errors[:interests]).to include('contains an invalid category')
    end
  end
end