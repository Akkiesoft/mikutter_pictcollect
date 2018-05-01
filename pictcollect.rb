# 画像これくしょん(mikutter3.2以降)

require "open-uri"
require 'net/http'
require 'uri'
require 'fileutils'

Plugin.create(:pictcollect) do
  defactivity "pictcollect", "画像これくしょん"

  def get_savedir()
    savedir = UserConfig[:collect_savedir]
    if (FileTest.exist?(savedir))
      # 保存先ディレクトリの取得と必要に応じて/の補完
      return savedir + "/" if savedir !=~ /\/$/
    else
      activity :pictcollect, "先に保存先ディレクトリを指定してください"
      return nil
    end
  end

  # From http://d.hatena.ne.jp/gan2/20080531/1212227507
  def save_file(url, filename)
    Thread.new(url) { |url|
      if File.exist?(filename)
        activity :pictcollect, "もうある #{filename}"
      else
        open(filename, 'wb') do |file|
          open(url) do |data|
            file.write(data.read)
          end
        end
        activity :pictcollect, "ほぞんした！！ #{url} --> #{filename}"
      end
    }
  end

  def pictcollect(message, savedir)
    # ツイートに含まれる画像のURLを取得
    if (Plugin.instance_exist?(:score))
      # 3.7以降 
      urls = Plugin[:"pictcollect"].score_of(message).map(&:uri)
    else
      # 3.6以前
      urls = message.entity.select{ |entity|
        %i<urls media hatenafotolife>.include? entity[:slug]
      }
    end

    count = 1
    urls.map{ |url|
      Plugin.filtering(:openimg_raw_image_from_display_url, url.to_s, nil)
    }.select{ |pair| pair.last }.map(&:first).each{ |url|
      savedir_world = ""
      username = ""
      photo = Enumerator.new{ |y| Plugin.filtering(:photo_filter, url, y) }.first

      case message.class.slug
      when :twitter_tweet
        saveurl = photo[:original].uri.to_s
        filename = [message[:user][:idname], message[:id].to_s, count].join("_") + File.extname(url)
        username = message[:user][:idname]
      when :hatenahaiku_entry
        # TBD
        savedir_world = "!hatenahaiku/"
      when :worldon_status
        saveurl = photo[:original].uri.to_s
        filename = [message[:account][:acct], message[:id].to_s, count].join("_") + File.extname(url)
        username = message[:account][:acct]
        savedir_world = "!mastodon/"
      else
        activity :pictcollect, "未対応のWorldです"
        return
      end

      if filename
        savedir_usr = ""
        # ユーザーごとにディレクトリを掘る場合
        if (:collect_mkdir_by_account)
          savedir_usr = savedir_world + username + "/"
          if (! Dir.exist?(savedir + savedir_usr))
            FileUtils.mkdir_p(savedir + savedir_usr)
          end
        end
        count += 1
        save_file(saveurl, savedir + savedir_usr + filename)
      end
    }
  end

  command(
    :pictcollect,
    name: '画像をこれくしょんする',
    condition: lambda{ |opt| true },
    visible: true,
    role: :timeline
  ) do |opt|
    begin
      savedir = get_savedir()
      next unless (savedir)
      # 選択されたツイートに対してそれぞれ実行
      opt.messages.each { |message|
        pictcollect(message, savedir)
      }
    rescue => msg
      activity :pictcollect, msg.to_s
    end
  end

  command(:bulk_collect,
    name: 'まとめて画像これくしょん',
    condition: lambda{ |opt| true },
    visible: true,
    role: :postbox
  ) do |opt|
    savedir = get_savedir()
    next unless (savedir)

    urls = Plugin[:gtk].widgetof(opt.widget).widget_post.buffer.text
    Plugin[:gtk].widgetof(opt.widget).widget_post.buffer.text = ""
    urls.each_line { |url|
      # osa_kさんのshow_tweetを参考にした
      if id = url.match(/\d+$/)
        Thread.new{
          Message.findbyid(id[0].to_i)
        }.next {|message|
          pictcollect(message, savedir)
        }.terminate {|e|
          activity :pictcollect, "このツイートはこれくしょんできませんでした #{url} -> #{e.to_s}"
        }
      end
    }
  end

  settings "画像これくしょん" do
    input("画像を保存するディレクトリ", :collect_savedir)
    boolean('アカウントごとにディレクトリを作成', :collect_mkdir_by_account)
  end

end
