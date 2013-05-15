# todayTwits.rb @VERSION
#
# Copyright (c) 2008 Libby Miller
# Licensed under the MIT (MIT-LICENSE.txt)

require 'rubygems'
require 'uri'
require 'open-uri'
require 'net/http'
require 'json/pure'
require 'sqlite3'
require 'twitter'

# This class, which you should cron to run every five minutes, looks in the database to find out what programmes are on now
# and announces it on Twitter

class TodaysTwits

    # Get anything now or in the next 5 mins - non-inclusive for 5 mins' time
    # So at 55, things at 00 will have to wait for the next thing
    # but 58 will be caught
    SQL_SELECT_NEXT_PROG = "select * from beeb where time(starttime) >= time('now') AND time(starttime) < time('now', '+5 minutes');"

    @db = SQLite3::Database.open('beeb.db')

    def TodaysTwits.post(text)

        # get these configuration parameters by creating a new app from https://dev.twitter.com/apps

        Twitter.configure do |config|
           config.consumer_key = ""
           config.consumer_secret = ""
           config.oauth_token =  ""
           config.oauth_token_secret = ""
        end

      limit = nil

      # check rate limit status

      begin
        limit = Twitter.rate_limit_status
      rescue Exception=>e
        puts "error getting rate limit #{e}"
        e.backtrace
      end

      # tweet

      if(limit && limit["remaining_hits"] > 0)
        begin
           Twitter.update(text)
           puts "TWEETED #{text}"
        rescue Exception=>e
           puts "exception tweeting #{e}"
        end
      end

    end


    begin
        arr = []

        @db.results_as_hash = true
        rows = @db.execute(SQL_SELECT_NEXT_PROG);

        # generate the messages and put them in an array

        rows.each do |row|

            title = row["TITLE"]
            subtitle = row["SUBTITLE"]

            if subtitle =~ /\d{2}\/\d{2}\/\d{4}/
                # it's just a date so ignore it
            else
                title = title + ": " + subtitle
            end

            if title.length > 70
              title = title[0, 66]+"..."
            end

            pid = row["PID"]

            # is this going to start in the future or starting this minute?
            # what's the difference between the starting minute and the current minute?
            starttime = row["STARTTIME"]

            timeTilStart = Time.parse(starttime) - Time.now

            # Text niceness
            progInfo = "#{title} http://www.bbc.co.uk/programmes/#{pid}"

            if timeTilStart == 0
              arr.push("Starting now on Radio 4: " + progInfo)
            else
              if(timeTilStart > 0)
                arr.push("In a few minutes on Radio 4: " + progInfo)
              else
                arr.push("Just started on Radio 4: " + progInfo)
              end
            end

            puts "#{arr.length} items to send"
        end

        # The longest message looks like this:
        # "In a few minutes on Radio 4: TITLE http://www.bbc.co.uk/programmes/b00pnpn0"
        # It is 30 chars + link (16) + title, leaving us 96 chars for TITLE and SUBTITLE

        # Send the found data to Twitter
        # we may have more than one message
        x = 0
        while x < arr.length
          puts arr[x]
          TodaysTwits.post(arr[x])
          sleep 1
          x = x + 1
        end

    rescue Exception => error
        puts "There was an error doing stuff: " + error.backtrace.join("\n")
    end

end



