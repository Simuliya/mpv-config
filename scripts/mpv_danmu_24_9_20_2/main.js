// 视频信息
var video_name = "";
var video_full_name = "";
var video_path = "";

// 进度
var playback_time = 0;

// 获取脚本路径
var directory = mp.get_script_directory();

// 是否有node环境
var has_env = "0";
var serve = {
  0: directory + "/nodejs_serve/app-win.exe",
  1: directory + "/nodejs_serve/app.js",
};
var serve_path = serve[has_env];

// 保存的弹幕名
var danmu_name = "";
// 弹幕样式
var danmu_conf = {
  //分辨率
  "--resolution": "1920 1080",
  //速度
  "--scrolltime": "12",
  //字体
  "--fontname": "LXGW WenKai Mono Bold",
  //大小
  "--fontsize": "30",
  //透明度 1-255
  "--opacity": "128",
  //阴影
  "--shadow": "0",
  //粗体 true false
  "--bold": "true",
  //弹幕密度 整数   (>=-1) | -1     表示不重叠 |  0     表示无限制 |  其他     表示限定条数
  "--density": "0",
  //描边 0-4
  "--outline": "1",
};
// 弹幕路径
var danmu_directory = directory + "/danmu_download";

// 弹幕条数
danmu_count = 0;

// ass控制代码
var ass_start = mp.get_property_osd("osd-ass-cc/0");
var ass_stop = mp.get_property_osd("osd-ass-cc/1");

/////////////////////////////////////////////////////////////////////
// 监听视频路径变化  一般只会执行1次，拖入xml并转换会执行3次
mp.observe_property("path", "string", function (name) {
  // 如果路径存在
  if (mp.get_property("path")) {
    // 获取文件名  只是获取文件，不一定是视频
    var file_name = mp.get_property("filename");

    // 获取视频文件名 在是视频的情况下删除后缀
    if (file_name.match(/\.(mp4|mkv)$/)) {
      video_full_name = file_name;
      video_name = file_name.replace(/\.(mp4|mkv)$/i, "");
      video_path = mp.get_property("path");
    }

    // 获取视频名后设置弹幕名
    danmu_name = video_name + "_danmu";

    // 文件路径
    var file_path = mp.get_property("path");
    // 文件所在位置
    var file_directory = file_path
      ? file_path.replace(mp.get_property("filename"), "")
      : "";
    print("路径" + file_path + "文件夹" + file_directory);

    /////////////////////////////////////////////////////////////////
    // 执行命令函数 专用于与node程序通信
    // arg: 命令参数数组
    // _fn: 回调函数
    function command(arg, _fn) {
      // 判断是否优环境
      if (has_env === "1" && arg[0] === serve_path) {
        arg.unshift("node");
      }
      print("command执行:" + arg);
      // 异步执行命令
      mp.command_native_async(
        {
          name: "subprocess",
          playback_only: false, // 不仅在播放时运行
          args: arg,
          capture_stdout: true, // 捕获标准输出
        },
        function (res, val, err) {
          print("command_err:" + JSON.stringify(err));
          print("command_val:" + JSON.stringify(val));
          // 执行回调函数
          if (_fn) {
            _fn(res, val.stdout, err);
          }
        }
      );
    }

    // 文件操作函数集
    var FILE_FN = {
      // 删除文件
      del: function (_fn) {
        var arg = [
          serve_path,
          JSON.stringify({
            methods: "del",
            path: danmu_directory + "/" + danmu_name + ".xml", // 删除xml文件
          }),
        ];
        command(arg, _fn);
      },

      // 移动文件
      mv: function (_fn) {
        var arg = [
          serve_path,
          JSON.stringify({
            methods: "mv",
            old_path: danmu_directory + "/" + danmu_name + ".ass", // 旧路径
            new_path: file_directory + "/" + danmu_name + ".ass", // 新路径
          }),
        ];
        command(arg, _fn);
      },
    };

    // 弹幕操作函数集
    var DANMU_FN = {
      // 匹配弹幕
      get_match: function (video_name) {
        // 网络源大概率无法获取文件名
        if (!video_name) {
          var text = [{ text: "未能获取文件名，请手动输入" }];
          DANMU_FN.add_input_option(text);
          OSD_UI.creat_osd_text_ui(text);
          return;
        }

        // 显示OSD消息
        OSD_UI.creat_osd_text_ui([
          { text: video_name + "\n获取匹配列表中..." },
        ]);

        // 弹弹play匹配弹幕参数
        var fileName = video_name;
        var fileHash = "fae0b27c451c728867a567e8c1bb4e53"; // 文件哈希 随便写的
        var videoDuration = mp.get_property("duration"); // 视频时长
        var fileSize = mp.get_property("file-size"); // 文件大小
        var matchMode = "hashAndFileName"; // 匹配模式

        // 命令参数
        var arg = [
          serve_path,
          JSON.stringify({
            methods: "match",
            file_conf: {
              fileName: fileName,
              fileHash: fileHash,
              videoDuration: videoDuration,
              fileSize: fileSize,
              matchMode: matchMode,
            },
          }),
        ];
        // 获取匹配列表后的回调
        var b_fn = function (res, val, err) {
          // 解析JSON数据
          val = JSON.parse(val);
          // 参数返回正确
          if (val.state) {
            print(JSON.stringify(val.matches));
            // 匹配列表
            var listData = [];
            // 添加进表格
            for (var i = 0; i < val.matches.length; i++) {
              listData.push(DANMU_FN.creat_match_item(val.matches[i]));
            }

            listData = listData.slice(0, 10); // 最多显示10个列表项
            if (listData.length === 0) {
              listData.push({ text: "未能匹配到该番剧名称" });
            }

            // 添加手动输入项
            DANMU_FN.add_input_option(listData);

            // 绘制匹配列表
            OSD_UI.creat_osd_text_ui(listData);
          } else {
            print(JSON.stringify(val));
            // 显示OSD消息
            mp.osd_message(
              ass_start + "{\\1c&H0000FF&}" + "API匹配阶段失败" + ass_stop,
              2
            );
          }
        };

        // 执行命令
        try {
          command(arg, b_fn);
        } catch (error) {
          OSD_UI.close_ui(0);
          mp.osd_message(
            ass_start + "{\\1c&H0000FF&}" + "API匹配阶段失败" + ass_stop,
            2
          );
        }
      },

      // 创建osd_ui需要的匹配列表项
      /**
       * @description:
       * @param {{animeTitle,episodeTitle,episodeId}} item
       * @return {void}
       */
      creat_match_item: function (item) {
        return {
          text: item.animeTitle + item.episodeTitle, // 列表项信息
          fn: function () {
            DANMU_FN.DO_IT(item.episodeId); // 在每个匹配项按下回车添加执行加载弹幕操作
          },
        };
      },

      // 为匹配好的列表添加手动输入的选项
      add_input_option: function (listData) {
        // 添加手动输入的选项
        // 命令参数
        var arg = [
          serve_path,
          JSON.stringify({
            methods: "input",
            nodejs_serve: directory + "/nodejs_serve",
          }),
        ];

        listData.push({
          text: "手动输入番剧名",
          fn: function () {
            OSD_UI.creat_osd_text_ui([{ text: "正在匹配信息" }]);
            command(arg, function (res, val, err) {
              // 获取返回结果
              val = JSON.parse(val);
              if (err || !val.state) {
                OSD_UI.creat_osd_text_ui([{ text: "手动输入功能出错" }]);
                OSD_UI.close_ui(2000);
                return;
              }

              var list = [];
              for (var i = 0; i < val.animes.length; i++) {
                list.push(DANMU_FN.creat_match_item(val.animes[i]));
              }
              DANMU_FN.add_input_option(list);
              OSD_UI.creat_osd_text_ui(list);
              // DANMU_FN.get_match(val.data)
            });
          },
        });
      },

      // 用 search api搜索弹幕
      search: function () {},

      // 执行所有操作
      DO_IT: function (episodeId) {
        // 下载弹幕
        DANMU_FN.download(episodeId, function () {
          // 弹幕转换
          DANMU_FN.xml_to_ass(
            danmu_directory + "/" + danmu_name + ".ass",
            danmu_directory + "/" + danmu_name + ".xml",
            function () {
              // 加载弹幕
              DANMU_FN.load_danmu();
            }
          );
        });
      },

      // 下载弹幕 xml
      download: function (episodeId, _fn) {
        // 显示OSD消息
        OSD_UI.creat_osd_text_ui([{ text: "下载弹幕中..." }]);
        var arg = [
          serve_path,
          JSON.stringify({
            methods: "get_danmu",
            episodeId: episodeId, // 剧集ID
            // 弹幕下载路径
            directory: danmu_directory,
            fileName: danmu_name,
          }),
        ];

        // 执行命令
        command(arg, function (res, val, err) {
          print(val);
          // 解析JSON数据
          val = JSON.parse(val);
          if (val.state) {
            // 下载成功
            OSD_UI.creat_osd_text_ui([{ text: "下载成功,开始转换ass..." }]);
            danmu_count = val.count; // 弹幕数量
            _fn(); // 执行回调函数
          } else {
            // 显示OSD消息
            OSD_UI.creat_osd_text_ui([{ text: "下载失败，详情查看控制台" }]);
            OSD_UI.close_ui(2000);
          }
        });
      },

      // 转换成ass
      xml_to_ass: function (out_file, input_file, _fn) {
        print("格式转换" + out_file);
        print("格式转换" + input_file);
        var arg = [
          directory + "/DanmakuFactory/DanmakuFactory_REL1.70CLI.exe", // 转换工具路径
          "-o",
          out_file,
          "-i",
          input_file,
          "--resolution",
          danmu_conf["--resolution"],
          "--scrolltime",
          danmu_conf["--scrolltime"],
          "--fontname",
          danmu_conf["--fontname"],
          "--fontsize",
          danmu_conf["--fontsize"],
          "--opacity",
          danmu_conf["--opacity"],
          "--shadow",
          danmu_conf["--shadow"],
          "--bold",
          danmu_conf["--bold"],
          "--density",
          danmu_conf["--density"],
          "--outline",
          danmu_conf["--outline"],
        ];
        command(arg, _fn);
      },

      // 加载弹幕 & 移动删除
      load_danmu: function () {
        // 删除xml文件
        FILE_FN.del(function () {});
        // 移动ass文件
        FILE_FN.mv(function (res, val, err) {
          var danmu_p = danmu_directory + "/" + danmu_name + ".ass"; // 弹幕文件路径
          // 如果移动成功
          if (JSON.parse(val).state) {
            danmu_p = JSON.parse(val).new_path; // 更新弹幕文件路径
          }

          OSD_UI.creat_osd_text_ui([
            { text: "弹幕已加载:" + danmu_count + "条" },
            {
              text: JSON.parse(val).state
                ? "弹幕已放置视频目录下"
                : "弹幕处在" + danmu_directory,
            },
          ]);
          OSD_UI.close_ui(2000);
          // 添加弹幕
          mp.commandv("sub-add", danmu_p);
        });
      },
    };

    // 设置
    var SETING = {
      //创建目录
      create: function () {
        var list = [
          {
            text: "弹幕合并",
            fn: SETING.merge,
          },
        ];
        // DANMU_FN.add_input_option(list)

        OSD_UI.creat_osd_text_ui(list);
      },

      // 合并文件
      merge: function () {
        // 获取文件轨道
        var tracks = mp.get_property_native("track-list");
        // print("tracks",tracks)

        // [{title,path,select:Boolean}]
        var sub_list = [];
        // 已经选中的数量，0-2
        var select = 0;
        var osd_list = [{ text: "请选择要合并的字幕,回车合并" }];

        for (index = 0; index < tracks.length; index++) {
          track = tracks[index];
          // 获取字幕轨道信息
          if (track.codec === "ass") {
            sub_list.push({
              title: track.title,
              path: track["external-filename"],
            });

            osd_list.push({ text: track.title, fn: function () {} });
          }
        }

        OSD_UI.creat_osd_text_ui(osd_list);
      },
    };

    // OSD文本UI函数集
    var OSD_UI = {
      // 字体样式
      font_style: {
        select: "{\\fs12,\\1c&18d734&}", // 选中样式
        miss: "{\\fs12,\\1c&e8e8e8&}", // 未选中样式
      },

      //判断osd是否在显示
      is_show: false,
      // 循环计时器
      timer: "",
      // 清除UI的定时器
      close_ui_timer: "",

      // 列表数据
      list: [],

      // 下标
      index: 0,

      // 快捷键
      key: {
        // 选择上一个
        up: {
          name: "up",
          key: "UP",
          methods: function () {
            OSD_UI.change_index(-1); // 改变下标
          },
        },

        // 选择下一个
        down: {
          name: "down",
          key: "DOWN",
          methods: function () {
            OSD_UI.change_index(1); // 改变下标
          },
        },

        // 确认选择
        enter: {
          name: "enter",
          key: "ENTER",
          methods: function () {
            if (OSD_UI.list[OSD_UI.index].fn) {
              OSD_UI.list[OSD_UI.index].fn(); // 执行列表项操作
            }
          },
        },

        // 退出
        exit: {
          name: "exit",
          key: "ESC",
          methods: function () {
            OSD_UI.close_ui(0);
          },
        },

        // 下列属于纯占用其他快捷键，以防止在使用当前脚本时，误启动其他脚本
        left: {
          key: "LEFT",
          name: "left",
          methods: function () {},
        },

        right: {
          key: "RIGHT",
          name: "right",
          methods: function () {},
        },
      },

      // 添加快捷键
      key_bingding: function () {
        for (var key in this.key) {
          if (this.key.hasOwnProperty(key)) {
            var item = this.key[key];
            mp.add_forced_key_binding(item.key, item.name, item.methods);
          }
        }
      },

      // 清除快捷键
      key_remove: function () {
        for (var key in this.key) {
          if (this.key.hasOwnProperty(key)) {
            var item = this.key[key];
            mp.remove_key_binding(item.name);
          }
        }
      },

      // 改变选项
      change_index: function (val) {
        var last = this.list.length ? this.list.length - 1 : 0; // 获取最后一个下标
        this.index = val + this.index; // 更新下标
        // 处理边界情况
        if (this.index < 0) {
          this.index = last;
        }
        if (this.index > last) {
          this.index = 0;
        }
        print(this.index, last);
        this.create(); // 重新绘制UI
      },

      // 绘制ui 不接受参数，
      create: function () {
        var list_str = "";

        // 构建列表字符串
        if (this.list.length > 0) {
          for (var i = 0; i < this.list.length; i++) {
            var item = this.list[i];
            list_str +=
              // 字体样式
              (this.index == i
                ? this.font_style.select
                : this.font_style.miss) +
              item.text +
              "\n";
          }

          // 绘制
          mp.osd_message(ass_start + list_str + ass_stop, 2);
        }

        // 判断是否需要定时器
        if (this.is_show) {
          return; // 如果OSD正在显示，则直接返回
        }
        this.is_show = true;

        // 一直显示 防止被其他脚本关闭
        this.timer = setInterval(this.create.bind(this), 500);
      },

      // 绘制OSD文本UI 接收要绘制的文本
      /**
       * @description: 绘制OSD文本UI 接收要绘制的文本
       * @param {[{ text:String,fn:Function}]} listData
       * @return {void}
       */
      creat_osd_text_ui: function (listData) {
        // 如果关闭UI，立即又绘制UI，则终止关闭ui的操作
        if (this.close_ui_timer) {
          clearTimeout(this.close_ui_timer);
        }
        // 重置下标
        this.index = 0;
        this.list = listData;
        // 绘制
        OSD_UI.create();
        OSD_UI.key_bingding();
      },

      // 关闭ui
      close_ui: function (time) {
        this.close_ui_timer = setTimeout(
          function () {
            this.is_show = false; // 标记OSD不再显示
            clearInterval(this.timer);
            this.timer = "";
            this.index = 0;
            mp.osd_message(""); // 清空OSD消息
            this.key_remove();
          }.bind(OSD_UI),
          time
        );
      },
    };

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // 通过快捷键启动
    mp.register_script_message("danmu_match", function () {
      DANMU_FN.get_match(video_name);
    });

    // 设置
    mp.register_script_message("danmu_set", SETING.create);

    ////////////////////////////////////////////////////////////////////////
    // 拖入xml文件时，直接解析成ass
    if (file_name.match(/\.xml$/)) {
      // 回到视频
      mp.commandv("loadfile", video_path);

      print("进度回转" + playback_time);

      // 解决冲突  在有其他进度恢复脚本的情况下，等一段时间再重新恢复进度
      setTimeout(function () {
        // 回到之前的进度
        mp.commandv("seek", playback_time, "absolute");
      }, 50);

      // // 弹幕转换
      DANMU_FN.xml_to_ass(
        file_directory + "/" + danmu_name + ".ass",
        file_path,
        function () {
          mp.commandv("sub-add", file_directory + "/" + danmu_name + ".ass");
        }
      );
    }
  }
});

///////////////////////////////////////////////////////////////////////
// 在文件切换之前，获取进度   mp4->xml->mp4 会执行3次，xml无法获得进度
mp.add_hook("on_unload", 9, function (a) {
  if (mp.get_property_number("playback-time")) {
    playback_time = mp.get_property_number("playback-time");
  }
  print("进度" + playback_time);
});
