# 处理文件有两个版本的脚本


## 0老脚本使用的是固定字节的末端追加
###  100个字节的标志位+1000个字节的内容

### 一键调用
```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/mvvideofile/all0.sh)"

```

## 1新的脚本就是采用 V+L+T结构进行末端追加

### 一键调用
```

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/markternu/markinfo/master/mvvideofile/all1.sh)"

```