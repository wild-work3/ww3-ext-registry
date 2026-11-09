# ww3-ext-registry — WW3 官方插件市场

本仓是 **WW3（wild-work3）唯一的官方插件市场**，根目录**平铺**注册文件：一个插件一个 `<id>.json`。
本仓**永不托管二进制**、**不做签名**、**不约定 release tag**——只收录「仓库地址 + 版本 + SHA-256」。

契约权威：[`docs/PLUGIN_REGISTRY.md`](https://github.com/wild-work3/wild-work3/blob/main/docs/PLUGIN_REGISTRY.md)（v2，W3-48）。
本 README 只是人读摘要，**以契约文档为准**。

> **当前状态**：本仓已上线（默认分支 `main`，`validate` workflow 通过），21 个注册文件 = 20 插件 + `main.json`。
> **首个真实可安装包已上线**：`workbuddy`（来自 `wild-work3/ww3-workbuddy-ext` 的 `v1.0.0` release），
> 由插件仓的 release workflow 自动生成条目并提 PR #1，review 后 squash 合并。
> 其余 19 个插件仓与 release 包尚未发布（`wild-work3/wild-work3` 也无 tag/release），所以这些条目现在**可见但装不上**
> （下载 fail closed，报「atom feed 里没有可识别的 tag」）。这是“先验通道、后补包”的中间态，不是缺陷。

---

## 1. 文件命名（硬规则）

- 只认根目录的 `*.json`；文件名必须匹配 `^[a-z][a-z0-9]*(-[a-z0-9]+)*\.json$`
  （kebab-case，小写字母开头，只允许 `a-z0-9-`）。
- 文件名（去 `.json`）= 文件里的 `id` = 包内 `manifest.json` 的 `id` = 插件数据归属前缀。
- **类型写在文件里**（`type: channel|hook|main`），不从文件名推断，所以没有 `-ext.json` / `-hook.json` 后缀。
- 子目录与非 `*.json` 根文件一律忽略（`.github/` 只放 CI）。

## 2. 一个注册文件长什么样

```jsonc
{
  "schema": 2,
  "id": "workbuddy",                 // = 文件名
  "type": "channel",                 // channel | hook | main
  "name": "WorkBuddy（国内版 / 国际版）",
  "description": "…",
  "author": "wild-work3",
  "repo": "https://github.com/wild-work3/ww3-workbuddy-ext",  // 插件自己的仓，不是本仓
  "icon": "workbuddy",
  "color": "#2f6bff",
  "status": "verified",              // verified | unverified | broken
  "conformance": { "pass": 47, "warn": 0, "fail": 0, "mode": "offline", "at": "2026-11-05" },
  "capabilities": { "control": ["models.list", "…"], "conversation": ["chat.generate"] },
  "updated_at": "2026-11-05T18:00:00Z",
  "versions": [
    {
      "version": "1.0.0",
      "file": "workbuddy-1.0.0.zip",        // 发布包文件名（必填，不带路径，必须 .zip）
      "sha256": "…64 位小写十六进制（zip 包体的摘要）…",
      "size": 2853915,
      "os": "windows", "arch": "amd64",
      "protocol": { "min": 1, "max": 1 },
      "gateway":  { "min": "1.0.0" },
      "changelog": "首个版本"
    }
  ]
}
```

**没有 `latest` 字段**：最新版由客户端按 `os`/`arch` 过滤后取 semver 最大者。
**没有 `asset` / `tag` / `url`**：包在哪由客户端按 `repo` + `version` 去发布页自己找。

`type: main` 特殊：`versions[]` 描述的是 **`main.zip`**（`ww3-core.exe` + `custom-api-ext.exe` + `loopguard-hook.exe`），
另有一个 `gateway` 对象只做展示——gateway **不自动更新**，只提示手动替换。

## 3. 客户端怎么用

1. 拉本仓 tarball（`codeload.github.com/wild-work3/ww3-ext-registry/tar.gz/refs/heads/main`）一次读全；
2. 每个 `<id>.json` 独立校验：坏文件只丢该文件并计入 `errors[]`，不影响其他插件；
3. 安装时按 **`repo` + `version` + `file`** 定位发布包：
   `tags.atom`（7KB，退 `releases.atom`）匹配 semver tag → 拼 `releases/download/<tag>/<file>` → 下载 → **强制校验 sha256**。
   三者合起来唯一定位一个文件（代理/直连拼接规则相同），不需要枚举资产列表、也没有「挑哪个 zip」的歧义；
4. **全程不用 `api.github.com`**（限流 + 代理不可用），也不用 `releases/latest`（可变指针）。

## 4. 发布一个新版本（插件作者）

1. 在你的插件仓跑 `bash build.sh --zip`，得到 `<id>-<version>.zip`（包根只有 `<id>-ext.exe` + `manifest.json`）；
2. 在你的插件仓打 release 并上传该 zip（**tag 名随意**，`v1.4.2` / `1.4.2` / `release-1.4.2` 都能被识别）；
3. workflow 计算该 zip 的 `sha256` 与 `size`，并把**文件名**写进 `versions[].file`，生成/更新本仓的 `<id>.json`，**提 PR**；
4. 合并后客户端下个 TTL（≤30min）或用户点「刷新」即生效。

> **可选的准入自检**（由**插件仓自己**决定，本仓不代跑、不做门禁）：在自己仓的 workflow 里跑
> `ww3-conformance --exe dist/<id>-ext.exe --json-summary out.json`，把摘要里的 `conformance` / `capabilities`
> 写进本 PR。**不跑这一步同样可以发布**——只有 `repo` / `version` / `file` / `sha256` 是必要信息。
> 填了这两个字段的好处：ww3 插件管理界面会多显示准入徽章与能力矩阵（见 `conformance/PLAN.md` §0.1）。

> 注：本仓**不验证** sha256。写错不会装坏——客户端下载完发现摘要不符会直接拒装（fail closed）。
> 写错 `version` / `repo` 同理：都是**明确的安装失败**，不会静默装上错东西。

## 5. 维护者审查清单

- `id` 与包内 `manifest.json` 一致；`type` 正确（渠道 vs 拦截器 vs 主程序）；
- `repo` 指向**插件自己的 GitHub 仓**（不是本仓、不是别人的仓）；
- `protocol` / `gateway` 区间合理（别声明需要协议 2 又把 `max` 写成 1）；
- `versions[]` 至少一条带合法 `sha256` 与 `file`（`file` 必须是 release 里真实存在的资产名，不带路径）；
- 合规：插件不得绕过 core 调度私自重试/换模型/吞错，`capabilities` 声明与实际一致；
- **不下载包、不验 sha256**（这是本仓明确不做的）。

## 6. 单文件失败不拖垮整份清单

| 情况 | 处置 |
|---|---|
| 文件名不合命名规则 | 忽略该文件，不记错误 |
| JSON 语法错 / `schema` 不认识 / `id` 与文件名不符 / 缺必需字段 / `id` 重复 | 该文件不采信，计入 `errors[]` |
| `versions[]` 某条不合法（缺 `sha256`/非 64hex、`file` 缺失或带路径） | 只丢那一条，其他版本仍可用 |
| `versions[]` 为空 | 商店里可见但 `installable:false` |

`errors[]` 会通过 gateway 的 `/gw/plugins/store/errors` 透出到面板，**不许静默吞掉**。

## 7. 手动安装（永远支持的逃生通道）

不符合契约托管要求（自建 Git、私有仓）的插件走手动安装，不进本仓：

```
<plugins>/<id>/<ver>/<id>-ext.exe     # hook 为 <id>-hook.exe
<plugins>/<id>/<ver>/manifest.json
<plugins>/<id>/current                # 内容 = 裸版本号，无换行
```

## 8. 信任模型（必读）

本仓**不做签名**是刻意决定（平铺 N 文件形态下没有单一清单可签，「每插件一把 key」被明确否掉）：

- 信任 = **GitHub 仓访问控制 + PR 审查 + 客户端 sha256 强制校验**；
- 因此能合并 PR 的人可以推送任意包（sha256 由他自己写，必然自洽）——这是社区协作的必要代价；
- 缓解：`main` 分支保护（只能 PR + 维护者 review 合并）；`status: verified` 只由维护者手工设置，
  面板对 `unverified` 显著标记；面板展示 `repo` 与 `author` 让用户自行判断来源。
