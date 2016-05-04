# 画像これくしょん(mikutter3.2以降)

require "open-uri"
require "FileUtils"
require "image_size"
require 'net/http'
require 'uri'


def get_savedir(pictcollect)
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

# From http://d.hatena.ne.jp/gan2/20080531/1212227507
def save_file(url, filename, pictcollect)
  Thread.new(url) { |url|
    open(filename, 'wb') do |file|
      open(url) do |data|
        file.write(data.read)
      end
    end
    activity :pictcollect, "ほぞんした！！ #{url} --> #{filename}"
  }
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
      savedir = get_savedir(:pictcollect)
      if (! savedir) break end

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
            filename = get_filename_for_twimg(url, savedir, count)
            count += 1
            save_file(saveurl, filename, :pictcollect)
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
              save_file(saveurl, filename, :pictcollect)
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
