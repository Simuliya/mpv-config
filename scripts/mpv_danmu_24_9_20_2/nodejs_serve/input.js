const readline = require('readline');
const fs = require('fs');

const args = process.argv.slice(2);
let arg = args[0];
console.log(arg);

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function askFirstQuestion() {
    rl.question('请输入番剧名称: 格式举例 摇曳露营 第三季\n', (name) => {
        if (name.trim() === '') {
            console.log('输入不能为空，请重新输入。');
            askFirstQuestion(); // 递归调用重新提问
        } else {
            const filePath = arg;
            fs.writeFile(filePath, name + "\n", (err) => {
                if (err) {
                    console.error('写入文件时出错:', err);
                }
                askSecondQuestion(); // 写入成功后询问第二个问题
            });
        }
    });
}

function askSecondQuestion() {
    rl.question('请输入剧集: 格式举例 1\n', (episode) => {
        if (episode.trim() === '') {
            console.log('输入不能为空，请重新输入。');
            askSecondQuestion(); // 递归调用重新提问
        } else {
            const filePath = arg;
            fs.appendFile(filePath, episode + "\n", (err) => {
                if (err) {
                    console.error('追加文件时出错:', err);
                } else {
                    console.log('数据已成功写入文件。');
                }
                rl.close(); // 结束 readline
            });
        }
    });
}

// 开始询问第一个问题
askFirstQuestion();
