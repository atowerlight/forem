require "rails_helper"

RSpec.describe EmailDigestArticleCollector, type: :service do
  let(:user) { create(:user) }

  describe "#articles_to_send" do
    context "when user is brand new with no-follow" do
      it "provides top 3 articles" do
        create_list(:article, 3, public_reactions_count: 40, featured: true, score: 40)
        articles = described_class.new(user).articles_to_send
        expect(articles.length).to eq(3)
      end

      it "marks as not ready if there isn't atleast 3 articles" do
        create_list(:article, 2, public_reactions_count: 40, score: 40)
        articles = described_class.new(user).articles_to_send
        expect(articles).to be_empty
      end

      it "marks as not ready if there isn't at least 3 email-digest-eligible articles" do
        create_list(:article, 2, public_reactions_count: 40, score: 40)
        create_list(:article, 2, public_reactions_count: 40, email_digest_eligible: false)
        articles = described_class.new(user).articles_to_send
        expect(articles).to be_empty
      end
    end

    context "when a user's open_percentage is low " do
      before do
        author = create(:user)
        user.follow(author)
        create_list(:article, 3, user_id: author.id, public_reactions_count: 20, score: 20)
        10.times do
          Ahoy::Message.create(mailer: "DigestMailer#digest_email",
                               user_id: user.id, sent_at: Time.current.utc)
        end
      end

      it "will return no articles when user shouldn't receive any" do
        articles = described_class.new(user).articles_to_send
        expect(articles).to be_empty
      end
    end

    context "when a user's open_percentage is high" do
      before do
        10.times do
          Ahoy::Message.create(mailer: "DigestMailer#digest_email", user_id: user.id,
                               sent_at: Time.current.utc, opened_at: Time.current.utc)
          author = create(:user)
          user.follow(author)
          create_list(:article, 3, user_id: author.id, public_reactions_count: 40, score: 40)
        end
      end

      it "evaluates that user is ready to receive an email" do
        Timecop.freeze(3.days.from_now) do
          articles = described_class.new(user).articles_to_send
          expect(articles).not_to be_empty
        end
      end
    end
  end
end
