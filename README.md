# ☁️ UploadCloud

> 专为 macOS 设计的极速云盘上传小工具：在 Finder（访达）中右键任意文件，一键秒传到 Cloudflare R2，生成可供 ChatGPT / Claude / 浏览器免密直接读取的分享链接。

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ✨ 核心特性

- 🖱️ **Finder（访达）深度集成**：右键菜单/快速操作直接唤起，支持单文件与多文件批量上传。
- 🤖 **AI 友好直链**：配合自定义域名，生成无障碍直链，ChatGPT、Claude 等模型可直接免认证解析。
- 🗂️ **本地可视化管理面板**：内建文件历史看板，实时搜索已传文件、一键重新复制链接、按大小/时间排序。
- 🗑️ **远端一键物理删除**：在看板中点击删除，直调 Cloudflare R2 接口彻底抹除云端文件（返回 404），防冗余、省空间。
- 🔒 **双模式安全分享**：
  - **公开直链**：基于自定义域名永久有效（如 `https://files.yourdomain.com/2026/10/17/img_103022.png`）。
  - **临时签名链接**：生成带过期时间的 S3 Presigned URL（默认 24 小时可配置），到期自动失效。
- ⚡ **无同名覆盖碰撞**：上传时自动注入秒级时间戳，防止同名文件被意外覆盖。
- 📋 **极速反馈**：上传完成自动同步复制到剪贴板，伴随清脆系统水滴提示音，无打扰无弹窗。
- 🛡️ **纯本地原生实现**：Swift 原生编写，无任何第三方重量级依赖，密钥仅存储在本地 `~/.uploadcloud/`。

---

## 📖 新手指南：Cloudflare R2 配置教程

在第一次使用之前，需要拥有一个 Cloudflare R2 存储桶和 API 密钥。

👉 **[点击查看：Cloudflare R2 存储桶创建与自定义域名绑定完整小白教程](./docs/CLOUDFLARE_R2_GUIDE.md)**

该教程包含图文级别的步骤拆解：
1. 创建 R2 存储桶 (Bucket)
2. 绑定自定义二级域名 (Custom Domain)
3. 创建具备对象读写权限的 R2 API Token
4. 获取 Account ID并在 UploadCloud 中一键保存测试

---

## 🚀 安装与使用

### 1. 一键构建与安装

克隆仓库后，执行项目目录下的设置脚本：

```bash
git clone https://github.com/<your-username>/uploadcloud.git
cd uploadcloud
chmod +x setup.sh
./setup.sh
```

脚本将自动：
- 安装 XcodeGen（如缺失）
- 编译并生成带精美 App 图标的 `UploadCloud.app` 安装到 `/Applications/`
- 在 Finder 右键服务中注册快捷操作

### 2. 启动并配置

在终端运行或在访达应用程序中双击打开：

```bash
open /Applications/UploadCloud.app
```

切换到 **「设置」** Tab，填入你的 Cloudflare R2 参数，点击 **测试连接**，显示绿色成功后点击 **保存配置**。

### 3. 日常使用

1. 打开 Finder，选中任意文件（图片、视频、PDF、代码等）。
2. **鼠标右键** → **「快速操作 (Quick Actions)」**：
   - ☁️ **上传到云盘 (公开)**
   - 🔗 **上传到云盘 (临时链接)**
3. 听到清脆提示音后，链接已在剪贴板中，直接在聊天框 `Cmd + V` 发给 AI 即可！
4. 随时打开 `UploadCloud.app` 的 **「已传文件」** Tab 查看历史、搜索、重新复制或一键从云端删除。

---

## 💻 命令行 (CLI) 支持

工具自带全功能终端 CLI 二进制：

```bash
# 上传为公开链接
~/.uploadcloud/uploadcloud --public /path/to/file.png

# 上传为临时签名链接
~/.uploadcloud/uploadcloud --presigned /path/to/doc.pdf

# 查看所有上传历史
~/.uploadcloud/uploadcloud --list

# 从云端物理删除指定文件（输入列表中显示的 ID）
~/.uploadcloud/uploadcloud --delete 837cb191
```

---

## 🏗️ 目录结构

```
uploadcloud/
├── CLI/                              # 命令行工具源码
│   └── CLI.swift
├── Shared/                           # 核心复用库
│   ├── AWSV4Signer.swift             # AWS Signature V4 纯 Swift 签名实现
│   ├── ConfigManager.swift           # 本地配置管理 (~/.uploadcloud/config.json)
│   ├── HistoryManager.swift          # 上传历史管理 (~/.uploadcloud/history.json)
│   ├── Models.swift                  # 数据结构模型
│   ├── NotificationManager.swift     # 剪贴板与原生音效/通知管理
│   └── R2Uploader.swift              # S3 兼容上传与物理删除客户端
├── UploadCloud/                      # macOS SwiftUI 主应用
│   ├── AppIcon.icns                  # 精美原生圆角拟物图标
│   ├── ContentView.swift             # R2 配置与连接测试页
│   ├── HistoryView.swift             # 文件历史看板 (搜索、复制、一键云端删除)
│   └── UploadCloudApp.swift          # TabView 双栏应用入口
├── UploadCloudExtension/             # 原生 FinderSync 扩展
│   └── UploadCloudFinderSync.swift
├── docs/                             # 使用手册与教程
│   └── CLOUDFLARE_R2_GUIDE.md        # R2 存储桶与域名绑定保姆级指南
├── project.yml                       # XcodeGen 工程规范
└── setup.sh                          # 一键环境安装与编译脚本
```

---

## 📄 License

[MIT License](LICENSE)
