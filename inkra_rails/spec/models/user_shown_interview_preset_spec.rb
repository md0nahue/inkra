require 'rails_helper'

RSpec.describe UserShownInterviewPreset, type: :model do
  let(:user) { create(:user) }
  let(:interview_preset) { create(:interview_preset) }
  let(:shown_preset) { create(:user_shown_interview_preset, user: user, interview_preset: interview_preset) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:interview_preset) }
  end

  describe 'validations' do
    it { should validate_presence_of(:shown_at) }
    
    it 'validates uniqueness of user_id scoped to interview_preset_id' do
      create(:user_shown_interview_preset, user: user, interview_preset: interview_preset)
      
      duplicate = build(:user_shown_interview_preset, user: user, interview_preset: interview_preset)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by shown_at descending' do
        older_record = create(:user_shown_interview_preset, shown_at: 2.days.ago)
        newer_record = create(:user_shown_interview_preset, shown_at: 1.day.ago)
        
        expect(UserShownInterviewPreset.recent.first).to eq(newer_record)
        expect(UserShownInterviewPreset.recent.last).to eq(older_record)
      end
    end

    describe '.for_user' do
      it 'filters by user' do
        user1 = create(:user)
        user2 = create(:user)
        user1_record = create(:user_shown_interview_preset, user: user1)
        user2_record = create(:user_shown_interview_preset, user: user2)
        
        expect(UserShownInterviewPreset.for_user(user1)).to include(user1_record)
        expect(UserShownInterviewPreset.for_user(user1)).not_to include(user2_record)
      end
    end

    describe '.before_date' do
      it 'filters records shown before given date' do
        old_record = create(:user_shown_interview_preset, shown_at: 5.days.ago)
        recent_record = create(:user_shown_interview_preset, shown_at: 1.day.ago)
        
        cutoff_date = 3.days.ago
        
        expect(UserShownInterviewPreset.before_date(cutoff_date)).to include(old_record)
        expect(UserShownInterviewPreset.before_date(cutoff_date)).not_to include(recent_record)
      end
    end
  end

  describe '.clear_old_records' do
    it 'deletes old records for specified user' do
      old_record = create(:user_shown_interview_preset, user: user, shown_at: 40.days.ago)
      recent_record = create(:user_shown_interview_preset, user: user, shown_at: 1.day.ago)
      other_user_old_record = create(:user_shown_interview_preset, shown_at: 40.days.ago)
      
      expect {
        UserShownInterviewPreset.clear_old_records(user, 30)
      }.to change { UserShownInterviewPreset.count }.by(-1)
      
      expect { old_record.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(recent_record.reload).to be_present
      expect(other_user_old_record.reload).to be_present
    end
  end

  describe '.reset_for_user' do
    it 'deletes all records for specified user' do
      user1 = create(:user)
      user2 = create(:user)
      
      user1_records = create_list(:user_shown_interview_preset, 3, user: user1)
      user2_records = create_list(:user_shown_interview_preset, 2, user: user2)
      
      expect {
        UserShownInterviewPreset.reset_for_user(user1)
      }.to change { UserShownInterviewPreset.count }.by(-3)
      
      expect(UserShownInterviewPreset.for_user(user1)).to be_empty
      expect(UserShownInterviewPreset.for_user(user2).count).to eq(2)
    end
  end
end