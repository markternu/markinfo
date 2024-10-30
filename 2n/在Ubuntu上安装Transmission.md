在Ubuntu上安装Transmission（一个流行的BitTorrent客户端）非常简单。可以通过Ubuntu的软件包管理工具apt来完成。下面是详细步骤：

更新软件包列表（确保系统的软件包是最新的）：

bash
复制代码
sudo apt update
安装Transmission：

通过以下命令安装Transmission的桌面版（带图形用户界面）：

bash
复制代码
sudo apt install transmission-gtk
如果你只需要Transmission的命令行版本，可以使用以下命令：

bash
复制代码
sudo apt install transmission-cli
如果你需要安装Transmission的Web界面版（可以通过浏览器控制），使用以下命令：

bash
复制代码
sudo apt install transmission-daemon
启动Transmission：

如果安装的是桌面版，安装完成后可以在应用程序菜单中找到并启动Transmission。

如果安装的是命令行版，可以使用命令行启动：

bash
复制代码
transmission-cli <torrent-file>
如果安装的是Web界面版，需要先启动服务：

bash
复制代码
sudo systemctl start transmission-daemon
启动后可以在浏览器中通过默认的http://localhost:9091访问Transmission的Web界面。

配置Transmission（可选）：

对于Transmission Daemon，可以通过编辑配置文件 /etc/transmission-daemon/settings.json 来更改设置，例如端口、下载目录等。

修改完成后，需要重启服务以应用更改：

bash
复制代码
sudo systemctl restart transmission-daemon
这样就可以在Ubuntu上安装并运行Transmission了！