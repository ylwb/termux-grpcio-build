# termux-grpcio-build

远程交叉编译仓库，分两阶段：

## 阶段 A：链路打穿（smoke）
目标：验证 GitHub 公仓远程环境可以交叉编译 aarch64 / Android / Termux 目标。

- workflow: `.github/workflows/smoke-aarch64-pipeline.yml`
- 内容：
  - `nttld/setup-ndk` 安装 NDK
  - 生成最小 aarch64 `.so`
  - 打包产物
- 不编 `grpcio`，不碰 boringssl / protobuf / Cython

## 阶段 B：真正编 grpcio
目标：远程产出可安装到 Termux 的 `grpcio` 扩展。

- workflow: `.github/workflows/build-grpcio.yml`
- 依赖 A 阶段验证过的 NDK 工具链

## 快速使用
```bash
git init
git add .
git commit -m "Add smoke + grpcio remote build pipeline"
gh repo create ylwb/termux-grpcio-build --public
git remote add origin git@github.com:ylwb/termux-grpcio-build.git
git push -u origin main
```

在 GitHub 上手动触发：
- 先跑 `smoke-aarch64-pipeline`
- A 通过后跑 `build-grpcio`

## 产物
- A: `dist/libsmoke_ext.so`
- B: `dist/grpcio-aarch64-termux.whl` 或 `cygrpc*.so`
