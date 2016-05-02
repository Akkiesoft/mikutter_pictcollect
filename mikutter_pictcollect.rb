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
        urls.each_with_index { |url, i|
          saved = nil
          case url[:slug]
          when :media
            # pic.twitter.com
            saveurl  = url[:media_url] + ":orig"
            activity :pictcollect, "[MEDIA] #{saveurl}"
            savebase = url[:expanded_url]
            savebase =~ %r{http://twitter.com/(.+)/status/(.+)/photo/([0-9]+)}
            filename = "#{savedir}#{$~[1]}_#{$~[2]}_#{i+1}" + File.extname(url[:media_url])
            Thread.new(saveurl) { |saveurl|
              save_file(saveurl, filename)
            }
            saved = 1
          when :urls
            # 他の画像サービス系
            saveurl = Plugin.filtering(
              :openimg_raw_image_from_display_url,
              url[:expanded_url], nil).first.to_s
            activity :pictcollect, "[URL] #{saveurl}"
            parseurl = URI.parse(saveurl)
            if parseurl.host == "pbs.twimg.com"
              parseurl.path += ":orig"
              ext="jpg"
            else
              response = nil
              Net::HTTP.start(parseurl.host, parseurl.port) {|http|
                response = http.head(parseurl.path)
              }
              ext = nil
              case response['content-type']
              when "image/png"
                ext = "png"
              when "image/gif"
                ext = "gif"
              when "image/bmp"
                ext = "bmp"
              when "image/jpeg"
                ext = "jpg"
              end
            end
			if ext
              filename = "#{savedir}#{message[:user]}_#{message[:id_str]}_#{i+1}.#{ext}"
              Thread.new(saveurl) { |saveurl|
                save_file(saveurl, filename)
              }
              saved = 1
            else
              activity :pictcollect, "skip #{saveurl}"
            end
          else
            activity :pictcollect, "Unknown type"
          end
          if saved
            activity :pictcollect, "ほぞんした！！ #{filename}"
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
