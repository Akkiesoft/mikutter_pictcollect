# 画像これくしょん(mikutter3.6以降)

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

  # From https://morizyun.github.io/ruby/tips-image-type-check-png-jpeg-gif.html
  def image_type(file_path)
    File.open(file_path, 'rb') do |f|
      begin
        header = f.read(8)
        f.seek(-12, IO::SEEK_END)
        footer = f.read(12)
      rescue
        return ''
      end

      if header[0, 2].unpack('H*') == %w(ffd8) && footer[-2, 2].unpack('H*') == %w(ffd9)
        return '.jpg'
      elsif header[0, 3].unpack('A*') == %w(GIF) && footer[-1, 1].unpack('H*') == %w(3b)
        return '.gif'
      elsif header[0, 8].unpack('H*') == %w(89504e470d0a1a0a) && footer[-12,12].unpack('H*') == %w(0000000049454e44ae426082)
        return '.png'
      end
    end
    return ''
  end

  # From http://d.hatena.ne.jp/gan2/20080531/1212227507
  def save_file(md5, url, filename)
    ret = Thread.new(url) { |url|
      saved = nil
      if File.exist?(filename)
        activity :pictcollect, "もうある #{filename}"
        saved = 2
      else
        begin
          open(filename, 'wb') do |file|
            URI.open(url) do |data|
              file.write(data.read)
            end
        rescue OpenURI::HTTPError => e
            activity :pictcollect, "ほぞんできないURL #{url} (#e)"
            saved = nil
          end
        end
        saved = 1
        # 拡張子を含まない場合は調べて付加する
        if (File.extname(filename) !~ /\.(jpg|jpeg|png|gif|mp4)$/ )
          old = filename
          ext = image_type(filename)
          if ext != ""
            filename += ext
            if File.exist?(filename)
              File.delete(old)
              activity :pictcollect, "もうある #{filename}"
            else
              File.rename(old, filename)
            end
          else
            File.delete(filename)
            activity :pictcollect, "ほぞんできないURL #{url}"
            saved = nil
          end
        end
      end
      if saved
        # check duplicate file
        m = Digest::MD5.file(filename)
        if (md5.include?(m))
          File.delete(filename)
          "duplicated"
        else
          if saved == 1
            activity :pictcollect, "ほぞんした！！ #{url} --> #{filename}"
          end
          m
        end
      end
    }
    return ret.value
  end

  def pictcollect(message, savedir)
    count = 1
    md5 = []
    # ツイートに含まれる画像のURLを取得
    Plugin[:"pictcollect"].score_of(message).map{ |url|
      Plugin.filtering(:openimg_raw_image_from_display_url, url.uri.to_s, nil)
    }.select{ |pair| pair.last }.map(&:first).each{ |url|
      savedir_world = ""
      username = ""
      photo = Enumerator.new{ |y| Plugin.filtering(:photo_filter, url, y) }.first
      case message.class.slug
      when :twitter_tweet
        saveurl = photo[:original].uri.to_s
        username = message[:user][:idname]
        filename = [username, message[:id].to_s, count].join("_") + File.extname(url)
      when :mastodon_status, :worldon_status
        saveurl = photo[:original].uri.to_s
        ext = File.extname(url)
        ext = (ext.include?("?")) ? ext.split("?")[0] : ext
        username = message[:account][:acct]
        filename = [username, message[:id].to_s, count].join("_") + ext
        savedir_world = "!mastodon/"
      else
        activity :pictcollect, "未対応のWorldです"
        return
      end

      if filename
        savedir_usr = ""
        # ユーザーごとにディレクトリを掘る場合
        if UserConfig[:collect_mkdir_by_account]
          savedir_usr = savedir_world + username + "/"
          if (! Dir.exist?(savedir + savedir_usr))
            FileUtils.mkdir_p(savedir + savedir_usr)
          end
        end
        count += 1
        savepath = savedir + savedir_usr + filename
        m = save_file(md5, saveurl, savepath)
        if m == "duplicated"
          count -= 1
        elsif m
          md5.push(m)
        end
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

    urls = Plugin[:gtk3].widgetof(opt.widget).widget_post.buffer.text
    Plugin[:gtk3].widgetof(opt.widget).widget_post.buffer.text = ""
    urls.each_line(chomp: true) { |url|
      # 金具さんのshow_tweetをパクった
      # https://github.com/cobodo/show_tweet/blob/req/any-model/show_tweet.rb
      diva_url = Diva::URI.new(url)
      model_class = Enumerator.new { |y|
        Plugin.filtering(:model_of_uri, diva_url, y)
      }.lazy.map{ |model_slug|
        Diva::Model(model_slug)
      }.find{ |mc|
        mc.spec.timeline
      }
      Delayer.Deferred.new{
        model_class.find_by_uri(diva_url)
      }.next{ |message|
          pictcollect(message, savedir)
      }.terminate {|e|
          activity :pictcollect, "このツイートはこれくしょんできませんでした #{url} -> #{e.to_s}"
      }
    }
  end

  settings "画像これくしょん" do
    input("画像を保存するディレクトリ", :collect_savedir)
    boolean('アカウントごとにディレクトリを作成', :collect_mkdir_by_account)
  end

end
