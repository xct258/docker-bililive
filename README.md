
主要用于自动录制上传括弧笑的直播

启动示例：
```
docker run -d   \
    --name debian-bililive   \
    --net=host   \
    -e XCT258_GITHUB_TOKEN=  `# github的token，用于下载配置文件`  \
    -e Bililive_USER=xct258  `# 录播姬默认用户名xct258`  \
    -e Bililive_PASS=xct258  `# 录播姬默认随机密码`  \
    -e Biliup_PASS=xct258  `# biliup默认用户名为biliup不可指定，biliup默认随机密码`  \
    -v /home/xct258/bililive:/rec  \
    xct258/debian-bililive
```
biliup默认端口19159
录播姬默认端口2356
