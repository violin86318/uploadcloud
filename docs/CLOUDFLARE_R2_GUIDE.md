# Cloudflare R2 存储桶创建与自定义域名绑定完整新手教程

> 本指南手把手带你从零配置 Cloudflare R2，让小工具生成能够让 ChatGPT、Claude 或任何人直接免密读取的文件链接。

---

## 目录
- [0. 什么是 Cloudflare R2？为什么用它？](#0-什么是-cloudflare-r2为什么用它)
- [1. 准备工作](#1-准备工作)
- [2. 创建 R2 存储桶 (Bucket)](#2-创建-r2-存储桶-bucket)
- [3. 绑定自定义域名（让文件可通过你的网址访问）](#3-绑定自定义域名让文件可通过你的网址访问)
- [4. 创建 R2 API 令牌 (获取密钥)](#4-创建-r2-api-令牌-获取密钥)
- [5. 获取账户 ID (Account ID)](#5-获取账户-id-account-id)
- [6. 在 UploadCloud 中填入并测试](#6-在-uploadcloud-中填入并测试)
- [7. 常见问题排查 (FAQ)](#7-常见问题排查-faq)

---

## 0. 什么是 Cloudflare R2？为什么用它？

- **免费额度巨大**：Cloudflare R2 每月提供 **10 GB 免费存储**，以及每月 100 万次上传写入、1000 万次读取请求。作为个人日常传图、传文档给 AI 使用，**几乎完全免费**。
- **0 出网流量费 (Zero Egress Fees)**：不同于亚马逊 AWS S3 昂贵的流量费，R2 访问下载完全不收流量费。
- **原生支持自定义域名**：可以绑定形如 `files.yourdomain.com` 的专属网址，自带免费 SSL 证书。

---

## 1. 准备工作

1. 一个 [Cloudflare 账号](https://dash.cloudflare.com/)（如果没有，先注册一个）。
2. 一个已经将 DNS 托管在 Cloudflare 上的域名（例如 `yourdomain.com`）。
   > 如果你还没有把域名托管到 Cloudflare，可以在 Cloudflare 控制台点击「添加站点」，按照提示把域名的 Nameservers 改到 Cloudflare。

---

## 2. 创建 R2 存储桶 (Bucket)

1. 登录 [Cloudflare 控制台](https://dash.cloudflare.com/)。
2. 在左侧导航栏中，点击 **R2 对象存储 (R2 Object Storage)**。
   *(如果是第一次使用 R2，页面会提示绑定一张信用卡以激活服务，扣费 0 元，不用担心超出)*
3. 点击页面右侧的 **创建存储桶 (Create bucket)** 按钮。
4. 填写基本信息：
   - **存储桶名称 (Bucket name)**：起一个纯英文和小写数字的名称，例如 `uploadcloud` 或 `files`。
   - **位置 (Location)**：保留默认的 `Automatic`（自动）。
5. 点击右下角的 **创建存储桶 (Create bucket)**。

创建完成后，页面会自动进入该存储桶的管理详情页。

---

## 3. 绑定自定义域名（让文件可通过你的网址访问）

为了让 AI（ChatGPT / Claude）无需登录即可直接读取你的图片和文档，需要为存储桶开启公开访问并绑定你的网址。

1. 在存储桶管理页面，切换到顶部的 **设置 (Settings)** 选项卡。
2. 向下滚动到 **公开访问 (Public access)** 区域。
3. 找到 **自定义域 (Custom Domains)**，点击右侧的 **连接域 (Connect Domain)** 按钮。
4. 在输入框中输入你想要分配给文件的二级域名：
   - 例如：你的主域名是 `qzz.io`，你可以输入 `upload.pom.qzz.io` 或 `files.qzz.io`。
5. 点击 **继续 (Continue)**。
6. Cloudflare 会自动识别该域名并在其 DNS 表中自动添加一条 `CNAME` 记录解析到 R2 存储桶。
7. 点击 **连接域 (Connect Domain)** 确认。
8. 稍等约 1~2 分钟，页面上的状态会从 `Pending` 变为绿色的 **已激活 (Active)**。

> 💡 **测试验证**：此时你的公开访问根地址就是：`https://你绑定的域名`（例如 `https://upload.pom.qzz.io`）。

---

## 4. 创建 R2 API 令牌 (获取密钥)

小工具需要通过 API 令牌来将文件上传到你的 R2 存储桶中。

1. 点击左侧导航栏的 **R2 对象存储** 返回 R2 概览页。
2. 在页面右侧找到 **账户详细信息** 下方，点击 **管理 R2 API 令牌 (Manage R2 API Tokens)**。
3. 点击 **创建 API 令牌 (Create API token)**。
4. 进行如下设置：
   - **令牌名称 (Token name)**：输入一个识别名称，比如 `UploadCloud-Mac`。
   - **权限 (Permissions)**：必须选择 **对象读和写 (Object Read & Write)**。
   - **适用于存储桶 (Apply to specific buckets)**：
     - 可以选择「所有存储桶」，也可以选择「仅限于特定存储桶」并勾选刚才创建的存储桶（如 `uploadcloud`）。
   - **TTL (有效期)**：选择默认的 **永久 (Forever)**，或按需设置。
5. 滚动到页面底部，点击 **创建 API 令牌 (Create API Token)**。
6. ⚠️ **极其重要**：创建成功后，页面会显示以下两个密钥，**离开页面后 Secret 将永远无法再次查看**，请立刻复制并妥善保存：
   - **访问密钥 ID (Access Key ID)**（通常为 32 位字符）
   - **机密访问密钥 (Secret Access Key)**（通常为 64 位字符）

---

## 5. 获取账户 ID (Account ID)

1. 点击左侧导航栏的 **R2 对象存储** 概览页。
2. 查看右侧栏的 **账户详细信息 (Account Details)**。
3. 复制其中的 **账户 ID (Account ID)**。

---

## 6. 在 UploadCloud 中填入并测试

现在你已经集齐了全部 5 项核心配置：

| 配置项 | 对应的值示例 | 说明 |
| :--- | :--- | :--- |
| **Account ID** | `eebf4ef6eda8a4cc3a49f9707cbe6978` | 在 R2 概览页右侧获取 |
| **Access Key ID** | `49b75d8e8204445e15259964e1acf15b` | 创建 API Token 时生成 |
| **Secret Access Key** | `a1b2c3d4...` | 创建 API Token 时生成 |
| **Bucket 名称** | `uploadcloud` | 创建存储桶时取的英文名字 |
| **自定义域名** | `upload.pom.qzz.io` | 刚刚绑定的自定义域名（无需写 `https://`） |

### 填入方式：
1. 打开 `UploadCloud.app`（或在终端运行 `open /Applications/UploadCloud.app`）。
2. 点击上方的 **「设置」** 选项卡。
3. 将上述 5 个参数填入对应的文本框中。
4. 点击 **「测试连接」**：
   - 看到绿色提示 `✅ 连接成功！测试文件: https://...` 说明一切正常！
5. 点击 **「保存配置」**。

恭喜！现在无论在 Finder 中选中什么文件，鼠标右键点击 **☁️ 上传到云盘 (公开)**，上传完成后地址就会秒速复制到剪贴板，直接粘贴发给 ChatGPT、Claude 等大模型即可！

---

## 7. 常见问题排查 (FAQ)

### Q1: 上传成功了，但打开链接显示 404 或 403 怎么办？
- **检查自定义域名状态**：回到 Cloudflare 控制台 → R2 → 进入存储桶 →「设置」→ 查看自定义域名是否显示为绿色的 `Active`。如果显示 `Pending`，通常需要等待几分钟让全球 DNS 生效。
- **检查域名书写**：在 UploadCloud 设置中填写自定义域名时，**不要**包含 `https://` 或末尾的斜杠 `/`，例如只填 `files.yourdomain.com` 即可。

### Q2: 临时链接模式（Presigned URL）生成的网址怎么不是我的自定义域名？
- 这是正常现象。预签名临时链接使用的是 S3 官方协议标准的 API 签名，链接指向的是 Cloudflare 官方 S3 端点（例如 `*.r2.cloudflarestorage.com/...`），自带签名参数和过期时间，任何人凭此链接均可直接访问，到期后自动失效，完美兼顾免密读取与隐私安全。

### Q3: AI 读取图片或文件时报错或读取失败？
- 确保上传模式使用的是 **「☁️ 上传到云盘 (公开)」**。公开链接在云端是全天候直链，各大模型的联网插件或多模态接口能够直接通过 HTTP GET 无障碍加载解析。
