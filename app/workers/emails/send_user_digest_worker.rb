module Emails
  class SendUserDigestWorker
    include Sidekiq::Worker

    sidekiq_options queue: :low_priority, retry: 15, lock: :until_executing

    def perform(user_id)
      user = User.find_by(id: user_id)
      return unless user&.email_digest_periodic? && user&.registered?

      articles = EmailDigestArticleCollector.new(user).articles_to_send
      return unless articles.any?

      begin
        DigestMailer.with(user: user, articles: articles).digest_email.deliver_now
      rescue StandardError => e
        Honeybadger.context({ user_id: user.id, article_ids: articles.map(&:id) })
        Honeybadger.notify(e)
      end
    end
  end
end
