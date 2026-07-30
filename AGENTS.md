# Agent 协作规范

版本：v1.0.0-260713-093516

本文件分为"标准内容"和"项目专用内容"。除非用户明确要求修改协作规范，否则只允许在"项目专用内容"下补充或调整，不修改标准内容。

## 标准内容

### 0. 文档缺失时先创建

- 如果当前仓库或当前子功能根目录没有 `AGENTS.md`，先阅读 `agent-template/AGENTS.md`，并在当前适用目录创建属于该目录自己的 `AGENTS.md`。
- 如果没有 `REQUIREMENTS.md`，先阅读 `agent-template/REQUIREMENTS.md`，并在当前适用目录创建属于该目录自己的 `REQUIREMENTS.md`。
- 如果没有 `DESIGN.md`，先阅读 `agent-template/DESIGN.md`，并在当前适用目录创建属于该目录自己的 `DESIGN.md`。
- 如果没有 `README.md`，先阅读 `agent-template/README.md`，并在当前适用目录创建属于该目录自己的 `README.md`。
- 如果仓库内已有内容，或已经与当前 Agent 进行过对话，基于仓库内的内容和对话的实际情况，填写上述文件，填写规则会在下文中写明。
- `AGENTS.md`、`REQUIREMENTS.md`、`DESIGN.md` 和 `README.md` 默认使用中文书写；除非用户特别说明，或术语、代码符号、专有名词本身应使用英文。
- `agent-template/` 中的 `README.md`、`REQUIREMENTS.md`、`DESIGN.md` 和 `agent-log/` 日志模板只保留演示内容；具体撰写规则统一以本 `AGENTS.md` 为准，阅读时需要注意分辨规则和示例的差异。
- 上述创建的文件名必须全大写；其中 `AGENTS.md` 和 `REQUIREMENTS.md` 必须使用复数形式。即使用户临时写成小写或单数，也应遵循该统一标准，除非用户明确要求修改。
- 由于本 template 本身也由 Git 管理，复制到实际仓库使用前，应先删除 `agent-template/` 中的 `.git` 等 Git 相关资产，移除其仓库特征，避免影响上层仓库管理。同时清理 `agent-log/` 中除日志模板文件 `yyyymmdd-hhmmss-utcpn-username-modelname.md` 以外的历史日志，避免把模板仓库的执行上下文带入新项目。
- 如果当前要初始化的是 Game 项目，必须改用 `game-agent-template/`，并在新项目仓库中默认启用 Git LFS；模板自带的 `.gitattributes` 必须一并复制到项目根目录，不得删改为普通 Git 跟踪，除非用户明确要求调整。
- Game 项目初始化时还必须一并复制模板自带的 `.gitignore`；`.gitignore` 负责忽略引擎缓存、构建产物、中间文件和其他不应入库的派生内容，规则应与资产管线、引擎和 `.gitattributes` 的跟踪边界保持一致。

### 1. 每次任务开始前

- 确认当前工作目录、分支和 worktree 是否符合用户本次明确指定的工作目标。
- 如果用户已经明确指定 feature、branch 或 worktree，且当前目录不匹配，Agent 可以按项目规则为用户进入已有 worktree，或创建对应 branch/worktree 后再执行任务。
- 如果用户没有明确指定目标分支或 feature，Agent 不得自行猜测并切换分支、创建分支或创建 worktree；应在当前分支继续，或停止并询问用户。
- 如果当前工作区存在未提交改动，Agent 不得切换分支、移动 worktree 或创建会覆盖现有路径的 worktree；必须先告知用户当前状态。
- 在 Git worktree 模式下，优先通过"进入已有 worktree"或"创建新的 worktree"来切换工作上下文，而不是在已有 worktree 内执行 `git checkout` / `git switch`。
- Agent 严禁在未获得用户明确授权的情况下执行 `git reset --hard`、`git clean`、`git branch -D`、`git worktree remove`、`git worktree move` 等破坏性命令。
- Git 同步预检规则：
  - `git fetch --prune`、`git merge --ff-only` 等同步操作需要直接访问远端仓库，**不应在断网或沙箱环境中静默执行**；如果当前执行环境默认禁止联网，应提示用户切换到允许网络访问的模式，否则无法完成同步预检。
  - 如果当前目录属于 Git 仓库，任务开始前先执行 `git fetch --prune`，只更新远端追踪信息，不直接修改本地工作区。
  - 然后检查当前分支是否设置了 upstream；如果没有 upstream，只记录当前分支状态，不执行 pull、merge 或 rebase。
  - 检查当前分支相对 upstream 的 ahead / behind 状态：
    - 如果没有落后远端，继续执行任务。
    - 如果本地没有未提交改动，且当前分支只落后远端，则执行 `git merge --ff-only @{u}`，只允许快进更新。
    - 如果本地存在未提交改动，先比较"本地已改文件"和"远端新增变更文件"是否重叠：
      - 如果没有重叠，可以执行 `git merge --ff-only @{u}`。
      - 如果存在重叠，停止执行并告知用户哪些文件同时被本地和远端修改。
    - 如果当前分支同时 ahead 和 behind，不自动 merge、不自动 rebase，停止执行并告知用户需要人工决定同步方式。
  - Agent 不主动执行普通 `git pull`，因为普通 `git pull` 可能隐式 merge 或 rebase，导致超出用户预期的历史变化。
- 如果发现当前分支、worktree、目录位置或任务基准不符合用户本次明确指定的工作目标，必须按上述规则处理，不得自行猜测目标上下文。
- 阅读用户本次原始 prompt。
- 阅读当前目录适用的 `AGENTS.md`、`README.md`、`REQUIREMENTS.md`、`DESIGN.md` 和 `agent-log/` 中的日志。日志的阅读规则如下：
  - 找到由当前 Agent / 对话创建的最新日志。
  - 如果有任何日志比该日志更新，阅读所有更新。
  - 如果没有，则不阅读任何日志。
  - 如果无法可靠判断"当前 Agent / 对话创建的最新日志"，则阅读最近 3 条日志，或阅读最近 7 天内的日志，并由 Agent 根据任务相关性取舍。
- 检查 `REQUIREMENTS.md`，确认用户本次需求是否匹配已有需求、子需求、验收项或已标记的阻塞项。
- 如果仓库内有父级与子级 `AGENTS.md`，从父到子依次阅读；更具体目录的规则优先，但不得违反父级标准内容和用户明确要求。

### 2. 每次任务执行中

- 为每次任务执行创建一条新的执行日志，放在当前适用目录的 `agent-log/`。
- 如果本次任务没有修改任何仓库文件，且只是解释、咨询、排查思路或一次性问答，可以不创建执行日志；但如果用户明确要求记录，或本次对话形成了新的需求、设计决策、技术约束，则仍应更新对应文档或日志。
- 日志命名规则：`YYYYMMDD-HHMMSS-utcpN-username-modelname.md` 或 `YYYYMMDD-HHMMSS-utcnN-username-modelname.md`。
- `utcpN` 表示 UTC 正偏移，`utcnN` 表示 UTC 负偏移；不要在文件名中使用 `+` 或 `-`，以确保不同系统和工具链的适配性，N 由实际数字代替。
- `username` 使用当前执行者或系统用户名称。
- `modelname` 必须使用本次执行实际使用的模型名称，且必须精确到具体的模型版本标识（例如 `claude-fable-5`、`gpt-5-6`），不得只写产品线或家族名（例如 `claude`、`gpt-5`），不得使用占位符、假设值或与其他模型混淆的名称；空格、斜杠、冒号、小数点等不适合作为文件名的字符统一替换为连字符 `-`。
- 如果运行环境只暴露家族名，应先确认实际模型版本；确实无法获得更具体版本时，使用能获取到的最具体标识，并在日志正文说明原因。
- 示例（仅说明格式，`<modelname>` 应替换为真实模型名）：`20260530-174209-utcp8-taobe-<modelname>.md`。
- 使用任务完成时间作为日志文件名中的时间；如果任务开始时先创建临时日志，交付前按完成时间重命名。
- 一次任务执行从 Agent 开始处理用户请求算起，到交付、提交、阻塞或明确暂停为止。
- 如果用户在同一次执行中补充或修正要求、引导对话，把补充 prompt 原文和时间追加到同一条日志。
- 如果上一次执行已经交付，用户提出新任务时创建新日志。
- 每条日志记录一次任务执行中的对话、行动和总结；中间过程可由 Agent 自行概括，但要足够支持后续接手。
- 每条日志开头必须包含：
  - 用户原始 prompt
  - 执行本次任务的具体模型版本，与文件名中的 `modelname` 一致
  - 启动运行时的分支和版本，也就是 Git 同步预检后实际所在分支与提交版本
  - 任务开始时间
  - 任务结束时间
  - 任务结束时是否执行了提交
- 每条日志还应包含：
  - 已阅读上下文
  - 对话与行动记录
  - 完成工作
  - 更新的需求 ID
  - 更新的 README 或 DESIGN 章节
  - 验证方式
  - 备注
- 日志模板文件只保留演示内容；日志命名、必填字段、撰写规则以本 `AGENTS.md` 为准。

### 3. REQUIREMENTS.md 的维护标准

- `REQUIREMENTS.md` 使用 Obsidian 原生友好的 Markdown 格式：标题层级、缩进任务列表、稳定 ID、少量标签。
- 不使用复杂表格。
- 不使用 YAML 字段。
- 通过标题分级拆分 Phase、branch/worktree 和 feature；Phase 命名、三级标题格式和 task ID 结构应遵循后文规则。
- 更频繁地通过缩进 checkbox 表达父子任务、子任务、验收项和检查点关系。
- 每个可执行需求必须有稳定 ID。
- 任务状态使用原生 Markdown checkbox：
  - `- [ ]` 表示未完成。
  - `- [x]` 表示已完成。
  - 阻塞、延后、取消在任务后追加 `#blocked`、`#deferred` 或 `#cut`。
  - 如果条目本身不适合涵盖已完成、未完成的信息，但确实需要被记录，则checkbox视作是否已读。
  - 如果条目本身既不适合记录是否已读、也不适合记录完成状态，但确实需要记录，则酌情使用有序、无序列表。
- 稳定 ID 不因排序、插入或移动而改变。
- 拆分任务时保留原 ID，并新增子 ID。
- 不静默删除需求；取消的需求保留并标记 `#cut`，附简短原因。
- 每次任务开始前，先检查 `REQUIREMENTS.md` 中是否已有匹配需求。
- 每次任务完成后，再根据本次记忆或重新检查 `REQUIREMENTS.md`，把已经完成的需求、子需求或验收项勾选为完成。
- 如果任务改变范围、状态、验收标准、优先级或阻塞条件，必须同步更新 `REQUIREMENTS.md`。
- 具体需求、验收标准、任务拆分、优先级、阻塞状态和完成状态只写入 `REQUIREMENTS.md`，不要写入 `README.md` 或 `DESIGN.md`。
- 修改 `REQUIREMENTS.md` 时，必须使用精准的局部修改，例如 patch、特定行替换或围绕目标 task 的小范围编辑。
- 严禁为了整理格式、重新排序或"优化表达"而单次大范围重写未涉及的 Phase、feature 或 task 历史。
- 除非用户明确要求重构需求文档，否则不得删除、合并、重编号或改写已有稳定 ID。
- 当用户通过对话反馈或新增需求，且该需求需要进入核心实现（例如应用代码、业务逻辑、数据结构或界面流程）时，应先将其整理为一条 requirement，再开始执行。新增 requirement 应优先归入现有 Phase；如果适合挂在已有 feature 或已有任务下，应由 Agent 自行判断并归入，不需要额外确认。若需要新建 Phase，或新增三级 feature 标题会影响 branch/worktree 规划、项目范围或 Phase 结构，必须先征询用户确认；如果只是把用户已经明确提出的需求归入一个自然的新 feature，且不涉及实际创建分支或 worktree，可以先记录，并在日志中说明原因。
- 条目的命名规则严格按照如下描述：
  - # 一级标题总是用于区分大的段落，例如哪部份是真的任务，哪部份是示例；真正的任务记录内容总是在第一个一级标题 #任务清单 下
    - 对于非任务清单下的内容，暂时不做特别约束，以项目为标准自行设计
  - ## 二级标题总是以 Phase 为单位区分，格式形如 `## Phase - v0.1.0 - xxx`；其中 `xxx` 可以按照实际情况填写该 Phase 的核心内容。
  - ### 三级标题总是以 feature 为单位区分，格式形如：`### branch-name: feature description`。
    - `branch-name` 同时表示该 feature 对应的 branch/worktree 名称，应保持 `a/b` 的两段式格式。
    - `a` 表示较稳定的大类、子系统、业务域或工作线；`b` 表示该大类下的具体分支名。
    - 如果暂时无法明确 `b`，使用 `main`，例如 `sub/main`；这样可以保留后续扩展为 `sub/xxx` 的空间。
    - 标题中的分隔符统一使用半角冒号加空格 `: `，不要使用中文全角冒号。
    - 冒号后的 `feature description` 描述该 branch 大类下一个用户可感知的完整 feature 或工作主题，例如 `添加 codex 订阅支持`。
    - feature 应描述用户、使用者或维护者能够感知到的能力、流程、页面、接口、内容包或交付物；不要用 `docs/main`、`qa/main` 这类任务分类替代 feature，除非项目本身的用户可感知功能就是文档、日志、测试报告等内容。
    - 一个 branch/worktree 下可以包含多个 feature，因此同一 Phase 内可以出现多个相同 `branch-name` 的三级标题，但冒号后的 feature description 必须不同。
    - 如果新增三级 feature 标题会影响 branch/worktree 规划、项目范围或 Phase 结构，必须先征询用户确认；如果只是把用户已经明确提出的需求归入一个自然的新 feature，且不涉及实际创建分支或 worktree，可以先记录，并在日志中说明原因。将新 task 归入已有 feature 时，由 Agent 根据语义自行判断即可。
    - 示例：
      - `### sub/main: 添加 codex 订阅支持`
      - `### sub/main: 整理订阅状态展示`
      - `### ui/profile: 重构用户页信息架构`
  - 三级标题以下不再继续拆分标题；所有具体事项都以 task 形式记录。每条 task 必须使用稳定 ID，并保持如下结构：
    - `[ ] \[0.1.0-DOC-A-001] 整理需求文档`
  - task ID 中的 `DOC-A`、`FE-A` 等表示具体任务分类，不属于 feature name；一个 feature 下可以包含多个分类、多个 task。
    - 分类前缀用于表达 task 的工作类型；字母后缀用于区分同一 feature 下相同分类的多组 task。
    - 同一 feature 内，同一分类的字母后缀按出现顺序递增；不同 feature 可重新从 `A` 开始。即使某类 task 只有一组，也默认使用 `A` 后缀。
    - 除非必要，否则不新增分类前缀；如果需要创建，咨询用户。可用分类前缀如下：
      - DOC：文档、说明、协作规范、需求整理、知识库维护。
      - PM：产品目标、范围定义、路线图、优先级、验收标准。
      - UX：用户体验、信息架构、用户路径、交互流程、可用性。
      - UI：界面视觉、设计系统、组件外观、响应式与可访问性。
      - FE：前端应用、客户端界面、状态管理、前端工程化。
      - BE：后端服务、业务逻辑、服务端接口、任务调度。
      - API：对外或内部接口契约、协议、Schema、SDK 集成边界。
      - DB：数据库、数据模型、迁移脚本、索引、查询与持久化。
      - DATA：内容数据、配置数据、导入导出、数据清洗、数据质量。
      - CONTENT：文案、素材、关卡、数值、运营内容等非代码内容资产。
      - QA：测试策略、自动化测试、人工验收、质量检查、回归验证。
      - OPS：部署、运维、监控、日志、告警、备份与恢复。
      - CI：持续集成、构建流水线、发布流程、版本管理自动化。
      - SEC：安全、权限、隐私、合规、密钥与敏感信息处理。
      - ARCH：系统架构、技术选型、模块边界、跨模块约束。
      - TOOL：开发工具、脚本、CLI、代码生成器、内部效率工具。

### 4. README.md 的维护纪律

- `README.md` 是项目对外的第一印象；它的目标读者是**第一次看到这个项目的人**，因此要让人愿意继续读下去。
- `README.md` 应聚焦"是什么 / 解决什么问题 / 当前状态 / 关键设计 / 入口文件 / 文档指针"这五到六件事，按读者关心的顺序组织；不要把所有信息塞进同一份文档。
- `README.md` 不应承担以下内容的承载职责；这些内容应放入**专门文件**，README 最多用一两句话提及并附 Markdown 链接：
  - 仓库结构、目录索引、文件清单 → `AGENTS.md` 的"项目专用内容"或专门的 `STRUCTURE.md`
  - 工作台、维护规则、协作流程、agent 角色 → `AGENTS.md`
  - 详细案例、章节速览、剧情梗概、关卡结构 → `canon/` `writing/outline/` 或 `wiki/`
  - 创作参考、对位作品、风格定位、参考作品 → `reference/`
  - 视觉规范、组件外观、UI 样式、设计 token → `DESIGN.md`
  - 任务清单、需求追踪、验收项、阻塞状态 → `REQUIREMENTS.md`
  - 完整命令清单、API 参考、配置项 → 专门的 `docs/` 或代码注释
- README 适合**指向**而不是**详述**。每段尽量用 1–3 句话概括核心，然后用 Markdown 链接指向详细文件；不要把详细文件的内容复制粘贴到 README。
- README 的语气**对外、对读者友好**；避免堆砌结构图、技术细节、内部术语和只对自己人有意义的缩写。第一次出现术语时，附简短说明。
- 当项目范围、关键设计、入口文件、当前状态或用户入口发生变化时，同步更新 `README.md`。
- 不要把具体待办、验收项、目录结构、协作规范、任务状态、案例速览、创作参考写进 `README.md`；这些内容写入其他专门文件。
- 当你不确定一段内容应该放在 README 还是其他文件时，问自己："这是给第一次看这个项目的人看的吗？" 如果不是，放到专门文件里。

### 5. DESIGN 维护纪律

- `DESIGN.md` 不是系统整体设计文档；它是视觉规范和界面风格文档。
- `DESIGN.md` 参考 Google Stitch / DESIGN.md 的语义：用 Markdown 描述 AI 和开发者可执行的视觉设计系统，包括颜色、字体、间距、布局、组件样式、视觉语气、响应式规则和可访问性约束。
- 如果该文件在首次创建时仓库中已有内容、或者已有 Agent 对话记录，则应该根据已有内容总结并创建符合实际情况的文件。
- `DESIGN.md` 用于让 AI 在实现 UI 时不猜测视觉风格；它不记录系统架构、数据模型、产品路线图或任务列表。
- 当品牌视觉、UI 风格、设计 token、组件外观、布局原则或可访问性规则变化时，同步更新 `DESIGN.md`。
- 如果项目没有 UI 或视觉界面，`DESIGN.md` 可只记录"不适用"和原因。
- 如果仓库中已有旧名 `DESIGNS.md` 且内容其实是系统/架构说明，后续整理时应迁移：系统/仓库/应用说明进入 `README.md`，视觉规范进入 `DESIGN.md`，具体需求进入 `REQUIREMENTS.md`。
- 如果项目的设计风格发生了大幅度、颠覆性的改变，应该将老版本的内容创建为一个 `DESIGN-yyyymmddhhmmss.md` 的文件，保存到根目录 `archive/design/`；如果该地址不存在，则创建。

### 6. 父子文档关系

- 如果仓库内有明显的多个子功能、子应用、子游戏、工具包或独立模块，应在根目录和每一层子功能根目录创建一套文档：
  - `AGENTS.md`
  - `README.md`
  - `REQUIREMENTS.md`
  - `DESIGN.md`
  - `agent-log/`
- 根目录 `README.md` 描述全局目标、共享约束、目录索引和跨子功能关系。
- 子功能 `README.md` 只描述该子功能独有的用途、入口、命令和边界，避免复制父级已有内容。
- 子功能 `DESIGN.md` 只描述该子功能独有视觉规范；如果沿用父级视觉规范，写明继承关系即可。
- 父级 `AGENTS.md` 必须索引子功能目录，并说明每个子功能的文档入口。
- 当一个任务只影响某个子功能时，优先更新该子功能的 `README.md`、`REQUIREMENTS.md`、`DESIGN.md` 和 `agent-log/`；如影响全局规则或跨子功能关系，再同步更新父级文档。
- 如果仓库中存在 `reference/`、`references/`、`third_party/`、`vendor/`、`examples/`、`project/` 等目录，并且其中嵌套了外部 GitHub 仓库、参考项目、示例项目或只读资料，这些目录不需要创建本规范涉及的文档；更新 `README.md`、`REQUIREMENTS.md`、`DESIGN.md` 和 `agent-log/` 时也不把这些外部参考仓库纳入项目自身范围，除非用户明确要求整理或改造这些目录。

### 7. 工程默认规则

- 优先遵循仓库已有技术栈、目录结构、命名和风格。
- 保持改动聚焦在用户请求范围内。
- 不覆盖用户改动，不回滚无关文件。
- 行为、共享逻辑或用户可见流程发生变化时，补充或更新测试。
- 交付前运行相关验证命令；如果无法运行，说明原因并记录剩余风险。
- 搜索优先使用 `rg`。
- 手工编辑文件优先使用补丁方式，避免产生无关格式化或大范围重写。

### 8. 目录命名规则

- 顶层目录应优先按照"交付物 / 职责"命名，而不是按照技术栈命名。目录名应该先回答"这个目录是什么用途"，而不是"它使用什么语言或框架"。
- 客户端形态应按交付平台或使用场景命名，例如：
  - Swift 原生 iOS 应用命名为 `ios/`。
  - macOS 原生应用命名为 `macos/`。
  - `web/` 仅用于真正的 Web App，并与 `ios/`、`macos/` 等客户端形态并列。
- 官网、宣传页、落地页应命名为 `site/`；管理后台应命名为 `admin/`；不要因为它们使用 TypeScript 就命名为 `ts/` 或 `ts-web/`。
- 如果某个交付物内部同时包含前端和后端，应在该目录下继续做二级拆分，例如 `site/frontend/` 与 `site/backend/`，而不是在顶层直接按技术栈或服务类型拆散。
- 只有当目录职责本身无法清楚表达，或者同一职责下存在多个技术实现时，才允许在名称中补充技术栈信息。
- 目录名应保持小写，使用连字符 `-` 分隔单词，避免重复项目名，也避免使用 `project` 这类信息量较低的泛称。

### 9. Worktree 工作目录模式

- 对于使用 Git worktree 的项目，推荐采用"项目容器目录不直接开发，`main` 有独立工作区，其他分支与 `main` 平级"的结构：

```text
<project-name>/              ← 项目容器目录，只收纳工作区，不作为任何分支的开发工作区
├── main/                    ← main 分支工作区，也是工具默认打开目录
│   ├── .git/                ← Git 元数据
│   ├── AGENTS.md
│   ├── README.md
│   ├── REQUIREMENTS.md
│   ├── DESIGN.md
└── <deliverable-dir>/   ← 例如 macos/、site/、ios/、web/、admin/
│
├── <branch-worktree-name>/  ← 其他分支工作区
├── <branch-worktree-name>/
└── _builds/                 ← 本地打包产物，不进 Git
```

- `<project-name>/` 是项目容器目录，只负责收纳 `main/` 和其他 branch worktree，不直接作为任何分支的开发工作区。
- `main/` 默认对应仓库默认主分支工作区；GitHub Desktop、Codex、其他 AI Agent 和 IDE 应优先打开 `main/` 目录，以便识别 repo、读取根文档，并发现同层其他 branch worktree。
- 其他 branch worktree 与 `main/` 平级，目录名应由用户或项目约定决定；当项目没有更具体规则时，推荐与 branch 名称保持一致。
- branch 名称中的 `/` 等不适合作为目录名的字符，在本地 worktree 目录名中替换为 `-` 或项目约定的安全分隔符。
- branch/worktree 名称推荐保持 `a/b` 的两段式格式；如果 `b` 暂不明确，使用 `main`，例如 `sub/main`，以保留后续扩展性。
- 仓库默认主分支 `main` 是特殊稳定分支，默认对应 `main/` 工作区。
- 每个 worktree 应对应一个明确的 Git branch；除非用户或项目规则另有说明，不在多个 worktree 中复用同一个 branch 作为长期开发工作区。
- 如果 branch 名称发生变更，关联的 worktree 本地目录名也应同步调整；如果 worktree 本地目录名发生变更，关联 branch 名称也应同步调整，以保持检索、定位和文档记录的一致性。
- 上述示例强调的是目录组织方式；`<project-name>`、`<branch-worktree-name>` 和 `_builds/` 只是占位符，不是强制命名规范。
- 如果用户已经明确指定 feature、branch 或 worktree，且当前目录不匹配，Agent 可以按项目规则优先进入已有 worktree；如确需创建对应 branch/worktree，应确保不会覆盖现有路径，并在执行前说明将要创建的 branch/worktree。
- 如果用户没有明确指定目标分支或 feature，Agent 不得自行猜测并切换分支、创建分支或创建 worktree；应在当前分支继续，或停止并询问用户。
- 禁止在未获得用户明确授权的情况下执行 `git worktree remove`、`git worktree move` 等会破坏或重定位 worktree 的命令。

### 10. 内容与系统任务日志拆分

- 针对更复杂的、同时存在"内容"和"系统"的项目，应在 `agent-log/` 下再创建两个文件夹：`agent-log/system/` 和 `agent-log/content/`。
- 每次实际执行任务时，应根据任务性质将日志记录到对应目录，而不是总是记录在同一个日志目录下。
- 内容和系统改动任务的分类由 Agent 根据上下文判断；通常来说，Web 系统的数据、游戏的装备数值和技能等属于内容更新。
- 如果一次任务同时涉及内容和系统，应优先记录在主要改动对应的目录，并在日志中说明另一类改动的范围。

## 项目专用内容

### 项目概况

- 项目名称：FreshLi4 Project Graph
- 产品简介：以 Godot 原生编辑器插件的形式扫描并可视化项目资产关系，形成可导航、可导出的项目知识图谱。
- 主要用户：维护中大型 Godot 4 项目的开发者、技术美术与 AI 辅助开发团队。
- 当前阶段：公开 MVP。

### 技术栈与命令

- 技术栈：Godot 4.4+、纯 GDScript、`EditorPlugin`、`GraphEdit`、JSON Schema v1。
- 统一入口：用 Godot 打开仓库根目录的 `project.godot`；可通过 `GODOT_BIN` 覆盖 Godot 可执行文件。
- 开发命令：`"${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" --editor --path .`
- 测试命令：`"${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" --headless --path . --script tests/test_runner.gd`
- 插件 smoke：`"${GODOT_BIN:-/Applications/Godot_mono.app/Contents/MacOS/Godot}" --headless --editor --path . --quit-after 120 -- --project-graph-smoke`
- 构建命令：本项目无需编译；GDScript 由 Godot 加载。
- 打包命令：发布时只打包 `addons/freshli4_project_graph/`。
- 发布命令：通过 GitHub Release 发布版本 ZIP；正式发版另行建立需求。

### 文档入口

- 项目说明：`README.md`
- 需求追踪：`REQUIREMENTS.md`
- 视觉规范：`DESIGN.md`
- 架构与数据边界：`docs/ARCHITECTURE.md`
- 图数据 Schema：`docs/SCHEMA.md`
- 执行日志：`agent-log/`

### 目录索引

- `addons/freshli4_project_graph/`：可复制到其他 Godot 项目的完整 addon。
- `addons/freshli4_project_graph/core/`：扫描、Ignore、有机力导向布局、Schema 与 JSON 持久化，不依赖编辑器 UI。
- `addons/freshli4_project_graph/ui/`：编辑器主界面与基础图视图。
- `tests/fixtures/`：扫描器自动测试使用的最小 Godot 资产。
- `tests/test_runner.gd`：无头测试入口。
- `docs/`：架构、Schema 与维护文档。
- `agent-log/`：当前工作区执行日志。
- `.github/workflows/`：持续集成。

### 子功能文档入口

- 当前没有需要独立维护文档的子交付物。

### App 类型补充约束

- Addon 核心保持纯 GDScript，不要求用户安装 .NET、Node.js、Tauri、浏览器运行时或数据库。
- 默认不扫描整个 `res://addons/`、Godot 生成目录和 `res://` 之外的引擎资源，避免图谱被工具实现污染。
- 自定义 Ignore 配置保存在 `user://freshli4_project_graph/`，并在目录遍历与依赖解析阶段同时生效。
- 扫描器不得实例化用户场景或执行用户脚本；只使用文件枚举与 `ResourceLoader` 依赖信息。
- 静态分析无法确认运行时行为时，必须在图数据中标为 `inferred`，不得输出为精确事实。
- 缓存与默认导出写入 `user://freshli4_project_graph/`，不自动修改被扫描项目的 `res://` 内容。
- 公共 API 和 Schema 变更必须更新 `docs/SCHEMA.md` 与版本号。
- 引用第三方实现时保留来源和许可证；当前 Phase 1 为 clean-room 实现。

### 维护提示

- 修改「标准内容」时，**必须**同步更新 `agent-template/app-agent-template/AGENTS.md` 与 `agent-template/game-agent-template/AGENTS.md` 的对应章节。
- 本文件应始终在「标准内容」原样保留的前提下，仅在「项目专用内容」追加或修改。
