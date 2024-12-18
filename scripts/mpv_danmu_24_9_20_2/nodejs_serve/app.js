
const fs = require("fs")
const axios = require("axios")
const { spawn } = require('child_process');

// 是否有环境
const input_env = false
// 接收的参数
const args = process.argv.slice(2);
let arg = JSON.parse(args[0]);


class DANMU {
    // 根据文件信息匹配弹幕 match接口
    static match = () => {
        let conf = {
            "fileName": arg.file_conf.fileName,
            "fileHash": "fae0b27c451c728867a567e8c1bb4e53",
            // "fileSize": arg.file_conf.fileSize,
            "fileSize": 0,
            // "videoDuration": arg.file_conf.videoDuration,
            "videoDuration": 0,
            "matchMode": "hashAndFileName"
        };

        try {
            axios.post("https://api.dandanplay.net/api/v2/match", conf)
                .then(res => {
                    console.log(JSON.stringify({ state: true, ...res.data }));
                })
                .catch(error => {
                    console.log(JSON.stringify({ state: false, error })); // 输出错误信息
                });
        } catch (error) {
            console.log(JSON.stringify({ state: false, error })); // 输出错误信息
        }
    }

    // 打开终端手动输入
    static input = () => {
        const nodejs_serve = arg.nodejs_serve
        const scriptPath = nodejs_serve + (input_env ? '/input.js' : '/input-win.exe')
        const input_path = nodejs_serve + "/input.txt"

        // 启动子进程
        const child = input_env ?
            spawn('cmd.exe', [`/c start /wait node ${scriptPath} ${input_path}`], { stdio: 'inherit' }) :
            spawn('cmd.exe', [`/c start /wait ${scriptPath} ${input_path}`], { stdio: 'inherit' })

        child.on('close', (code) => {
            // 读取 input.txt 文件的内容
            fs.readFile(input_path, 'utf8', (err, data) => {
                if (err) {
                    console.log(JSON.stringify({ state: false, err }));
                    return;
                }
                let d = data.split("\n")
                // 搜索弹幕
                DANMU.search(d[0], d[1])
                // // 清空
                fs.writeFile(input_path, "", (err) => { });
            });
        });
    }

    // 获取搜索结果 search接口
    static search = (name, episode) => {
        // let search_name = arg.name;

        try {
            axios.get(`https://api.dandanplay.net/api/v2/search/episodes?anime=${encodeURI(name)}&episode=${episode}`)
                .then(res => {
                    let animes = []

                    res.data.animes.forEach(a => {
                        let animeTitle = a.animeTitle
                        a.episodes.forEach(b => {
                            let episodeId = b.episodeId
                            let episodeTitle = b.episodeTitle
                            animes.push({animeTitle,episodeId,episodeTitle})
                        })
                    });
                    console.log(JSON.stringify({ state: true, animes }));
                })
                .catch(error => {
                    console.log(JSON.stringify({ state: false, error })); // 输出错误信息
                });
        } catch (error) {
            console.log(JSON.stringify({ state: false, error })); // 输出错误信息
        }
    }

    // 下载弹幕
    static get_danmu = () => {
        try {
            axios.get(`https://api.dandanplay.net/api/v2/comment/${arg.episodeId}?withRelated=true&chConvert=1`)
                .then(res => {
                    // 创建弹幕到本地
                    this.save_danmu(res.data.comments, arg.directory, arg.fileName, error => {
                        // 创建失败
                        if (error) {
                            console.log(JSON.stringify({ state: false, error })); // 输出错误信息
                        } else {
                            // 创建成功
                            console.log(JSON.stringify({ state: true, count: res.data.count }));
                        }
                    });
                })
                .catch(error => {
                    console.log(JSON.stringify({ state: false, error })); // 输出错误信息
                });
        } catch (error) {
            console.log(JSON.stringify({ state: false, error })); // 输出错误信息
        }
    }

    // json转xml到本地
    static save_danmu = (json_list, directory, fileName, __fun) => {
        // 转换xml
        let xml = '<?xml version="1.0"?><i>'
        for (let i in json_list) {
            const comment = json_list[i]
            const m = comment.m.replace(/</g, '<').replace(/>/g, '>').replace(/&/g, '&').replace(/"/g, '"')
            const arg = comment.p.split(',');
            const p = arg.slice(0, 2) + ',25,' + arg[2] + ',0,0,' + arg[3] + ',0'
            xml += '<d p="' + p + '">' + m + '</d>'
        }
        xml += '</i>'
        let file = `${directory}/${fileName}`
        // 写入到本地
        fs.writeFile(file + ".xml", xml, (error) => {
            __fun(error);
        });

        // 判断解析好的ass文件是否已存在
        if (fs.existsSync(file + ".ass")) {
            fs.unlinkSync(file + ".ass")
        }
    }

    // 删除文件
    static del = () => {
        fs.unlinkSync(arg.path, (err, data) => {
            if (err) {
                console.log(JSON.stringify({ state: false }));
            } else {
                console.log(JSON.stringify({ state: true }));
            }
        });
    }

    // 移动文件
    static mv = () => {
        fs.copyFile(arg.old_path, arg.new_path, (err, data) => {
            if (err) {
                console.log(JSON.stringify({ "message": "移动弹幕失败", state: false, erro: err }));
            } else {
                console.log(JSON.stringify({ "message": "移动弹幕成功", state: true, new_path: arg.new_path }));
                // 删除原来的
                fs.unlinkSync(arg.old_path)
            }
        });
    }
}

DANMU[arg.methods]();