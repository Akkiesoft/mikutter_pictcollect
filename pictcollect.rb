# 画像これくしょん(mikutter3.2以降)

require "open-uri"
require 'net/http'
require 'uri'

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

  def collect_twitter(message, url, savedir, count)
    case url[:slug]
    when :media
      # twimg.com
      saveurl = url[:media_url] + ":orig"
      url[:expanded_url] =~ %r{https?://twitter.com/(.+)/status/(.+)/photo/([0-9]+)}
      filename = "#{savedir}#{$~[1]}_#{$~[2]}_#{count}" + File.extname(url[:media_url])
    when :urls
      # 他のURLとか
      url = Plugin.filtering(
        :openimg_raw_image_from_display_url,
        url[:expanded_url], nil).first.to_s
      saveurl = URI.parse(url)
      filename = nil
      # pathがないURLはほぼ画像ではないだろう
      if saveurl.path != ""
        if saveurl.host == "pbs.twimg.com"
          # ココにtwimgが来る場合もあるので、きたら:origをつける
          saveurl.path += ":orig"
        end
        http = Net::HTTP.new(saveurl.host, saveurl.port)
        http.use_ssl = saveurl.scheme.include?("https")
        response = http.head(saveurl.path)
        if response['content-type'].include?("image")
          ext = response['content-type'].split("/")[1]
          filename = "#{savedir}#{message[:user]}_#{message[:id_str]}_#{count}.#{ext}"
        end
      end
    end
    return saveurl, filename
  end

  def pictcollect(message, savedir)
    # ツイートに含まれる画像のURLを取得
    urls = message.entity.select{ |entity|
      %i<urls media>.include? entity[:slug]
    }
    # ユーザーごとにディレクトリを掘る場合
    savedir += "#{message[:user]}/" if :collect_mkdir_by_account
    count = 1
    urls.each { |url|
    puts url
      # Twitter world
      if url[:from] == :twitter
        saveurl, filename = collect_twitter(message, url, savedir, count)
      end

      if filename
        count += 1
        if (:collect_mkdir_by_account && ! Dir.exist?(savedir) )
          Dir.mkdir(savedir, 0755)
        end
        save_file(saveurl, filename)
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
