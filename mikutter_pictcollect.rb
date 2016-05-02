# 画像これくしょん(mikutter3.2以降)

require "open-uri"
require "FileUtils"
require "image_size"
require 'net/http'
require 'uri'

# From http://d.hatena.ne.jp/gan2/20080531/1212227507
def save_file(url, filename)
  open(filename, 'wb') do |file|
    open(url) do |data|
      file.write(data.read)
    end
  end
end

Plugin.create(:mikutter_pictcollect) do
  defactivity "pictcollect", "画像これくしょん"
  
  command(
          :mikutter_pictcollect,
          name: '画像をコレクションする',
          condition: lambda{ |opt| true },
          visible: true,
          role: :timeline
  ) do |opt|
    begin
      savedir = UserConfig[:collect_savedir]
      if (! FileTest.exist?(savedir))
        raise "設定されているディレクトリが存在しません"
      end
      # 保存先ディレクトリの取得と必要に応じて/の補完
      if savedir !=~ /\/$/
        savedir = savedir + "/"
      end

      # 選択されたツイートに対してそれぞれ実行
      opt.messages.each { |message|
        # スレッド作成
        # ツイートに含まれる画像のURLを取得
        urls = message.entity.select{ |entity| %i<urls media>.include? entity[:slug] }
        count = 1
        urls.each { |url|
          case url[:slug]
          when :media
            # pic.twitter.com
            saveurl  = url[:media_url] + ":orig"
            savebase = url[:expanded_url]
            savebase =~ %r{http://twitter.com/(.+)/status/(.+)/photo/([0-9]+)}
            filename = "#{savedir}#{$~[1]}_#{$~[2]}_#{count}" + File.extname(url[:media_url])
            count += 1
            Thread.new(saveurl) { |saveurl|
              save_file(saveurl, filename)
              activity :pictcollect, "ほぞんした！！ [MEDIA] #{saveurl} --> #{filename}"
            }
          when :urls
            # 他の画像サービス系
            ext = ""
            save = nil
            url = Plugin.filtering(
              :openimg_raw_image_from_display_url,
              url[:expanded_url], nil).first.to_s

            saveurl = URI.parse(url)
            if saveurl.host == "pbs.twimg.com"
              # ココにtwimgが来る場合もあるので、きたら:origをつける
              saveurl.path += ":orig"
            end

            # 画像だったら保存
            response = nil
            http = Net::HTTP.new(saveurl.host, saveurl.port)
            http.use_ssl = true
            response = http.head(saveurl.path)
            if response['content-type'].index("image")
              ext = response['content-type'].split("/")[1]

              filename = "#{savedir}#{message[:user]}_#{message[:id_str]}_#{count}.#{ext}"
              count += 1
              Thread.new(saveurl) { |saveurl|
                save_file(saveurl, filename)
                activity :pictcollect, "ほぞんした！！ [URL] #{saveurl} --> #{filename}"
              }
#            else
#              activity :pictcollect, "skip #{saveurl} (Content-Type: #{response['content-type']})"
            end
#          else
#            activity :pictcollect, "Unknown type"
          end
        }
      }
    rescue => msg
      activity :pictcollect, msg.to_s
    end
  end
  
  settings "画像これくしょん" do
    input("画像を保存するディレクトリ",:collect_savedir)
  end

end
