require 'redd'
require 'yaml'

SUBREDDIT_TO_WATCH = 'provlux'
CACHE_FILENAME = "cache/#{SUBREDDIT_TO_WATCH}.yaml"
CROSSPOSTABLE_SUBREDDITS = %w(arlon libramont)

def cache
  unless File.exist?(CACHE_FILENAME)
    puts "cache is missing - create #{CACHE_FILENAME}"
    File.open(CACHE_FILENAME, "w+") do |file|
      file.write([].to_yaml)
    end
  end

  @cache ||= YAML.load(File.read(CACHE_FILENAME))
end

def save_cache
  File.open(CACHE_FILENAME, "r+") do |file|
    file.write(cache.to_yaml)
  end
end

session = Redd.it(
  user_agent: ENV['USER_AGENT'],
  client_id:  ENV['CLIENT_ID'],
  secret:     ENV['SECRET'],
  username:   ENV['REDDIT_USERNAME'],
  password:   ENV['REDDIT_PASSWORD']
)


while true do
  begin
    puts "loading comments"
    comments = session.subreddit(SUBREDDIT_TO_WATCH).listing(:new)

    comments.each do |comment|
      if cache.include?(comment.id)
        # This comment has already been seen, skip it
      else
        cache.push(comment.id)
        if comment.is_crosspostable
          potential_subreddit = comment.link_flair_text? ? comment.link_flair_text.downcase : nil
          if potential_subreddit && CROSSPOSTABLE_SUBREDDITS.include?(potential_subreddit)
            new_sub = session.subreddit(potential_subreddit)
            new_sub.submit("#{comment.title} (x-post from /r/#{SUBREDDIT_TO_WATCH})", url: 'https://www.reddit.com' + comment.permalink, resubmit: false, sendreplies: true)
            puts "crosspost `#{comment.title}` to r/#{potential_subreddit}, need to sleep 10 minutes now"
            save_cache
            sleep 10 * 60
          end
        end
      end
    end

    sleep 1200
  rescue Redd::APIError => err
    time_to_wait = (err.to_s.match(/[0-9]/).to_s.to_i * 60) + 10
    puts err
    puts "waiting #{time_to_wait} seconds"
    sleep time_to_wait
    retry
  end
end