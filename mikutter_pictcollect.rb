# 画像これくしょん(mikutter3.2以降)

require "open-uri"
require 'net/http'
require 'uri'

Plugin.create(:mikutter_pictcollect) do
  defactivity "pictcollect", "画像これくしょん"

  def get_savedir()
    savedir = UserConfig[:collect_savedir]
    if (FileTest.exist?(savedir))
      # 保存先ディレクトリの取得と必要に応じて/の補完
      if savedir !=~ /\/$/
        return savedir + "/"
      end
    else
      activity :pictcollect, "先に保存先ディレクトリを指定してください"
      return nil
    end
  end

  def get_filename_for_twimg(url, savedir, count)
    url[:expanded_url] =~ %r{http://twitter.com/(.+)/status/(.+)/photo/([0-9]+)}
    return "#{savedir}#{$~[1]}_#{$~[2]}_#{count}" + File.extname(url[:media_url])
  end

  def get_filename_for_url(message, url, savedir, count)
    saveurl = URI.parse(url)
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
    else
      filename = nil
    end
    return saveurl, filename
  end

  # From http://d.hatena.ne.jp/gan2/20080531/1212227507
  def save_file(url, filename)
    Thread.new(url) { |url|
      open(filename, 'wb') do |file|
        open(url) do |data|
          file.write(data.read)
        end
      end
      activity :pictcollect, "ほぞんした！！ #{url} --> #{filename}"
    }
  end

  def pictcollect(message, savedir)
    # ツイートに含まれる画像のURLを取得
    urls = message.entity.select{ |entity|
      %i<urls media>.include? entity[:slug]
    }
    count = 1
    urls.each { |url|
      case url[:slug]
      when :media
        # twimg.com
        saveurl  = url[:media_url] + ":orig"
        filename = get_filename_for_twimg(url, savedir, count)
      when :urls
        # 他のURLとか
        url = Plugin.filtering(
          :openimg_raw_image_from_display_url,
          url[:expanded_url], nil).first.to_s
        saveurl, filename = get_filename_for_url(
          message, url, savedir, count)
      end
      if filename
        count += 1
        save_file(saveurl, filename)
      end
    }
  end

  command(
    :mikutter_pictcollect,
    name: '画像をコレクションする',
    condition: lambda{ |opt| true },
    visible: true,
    role: :timeline
  ) do |opt|
    begin
      savedir = get_savedir()
      next if (! savedir)
      # 選択されたツイートに対してそれぞれ実行
      opt.messages.each { |message|
        pictcollect(message, savedir)
      }
    rescue => msg
      activity :pictcollect, msg.to_s
    end
  end

  settings "画像これくしょん" do
    input("画像を保存するディレクトリ", :collect_savedir)
  end

end
