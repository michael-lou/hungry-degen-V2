# HungryDegen 项目部署顺序

## 📋 概述

本文档描述 HungryDegen 项目的完整部署顺序。

## 🎯 部署顺序

### 阶段 1: 基础设施
```bash
# 1. 部署 DUST 代币 (ERC20)
npx hardhat run scripts/deploy-DUST.ts --network <network>

# 2. 部署并配置 ConfigCenter
npx hardhat run scripts/deploy-and-setup-configCenter.ts --network <network>

# 3. 部署 UserBalanceManager
npx hardhat run scripts/deploy-UserBalanceManager.ts --network <network>
```

### 阶段 2: 推荐系统核心
```bash
# 4. 部署并配置 ReferralV2 (包含 GoldDXP, SilverDXP, ReferralV2)
npx hardhat run scripts/deploy-and-setup-ReferralV2.ts --network <network>
```

### 阶段 3: NFT 系统
```bash
# 5. 部署并配置 CharacterNFTSale (依赖: ConfigCenter, ReferralV2)
npx hardhat run scripts/deploy-and-setup-CharacterNFTSale.ts --network <network>

# 6. 部署 BlackGhostSale (独立，如果未部署)
npx hardhat run scripts/deploy-blackghost-sale.ts --network <network>

# 7. 配置 BlackGhostSale 与 ReferralV2 的集成
npx hardhat run scripts/setup-BlackGhostSale-referralV2.ts --network <network>
```

### 阶段 4: 游戏机制
```bash
# 8. 部署 CharacterUpgrade (依赖: GoldDXP, SilverDXP, CharacterNFT, BlackGhostNFT)
npx hardhat run scripts/deploy-CharacterUpgrade.ts --network <network>

# 9. 部署并配置 CharacterNFTStaking (依赖: CharacterNFT, BlackGhostNFT, ConfigCenter)
npx hardhat run scripts/deploy-and-setup-CharacterNFTStaking.ts --network <network>
```

### 阶段 5: 市场系统
```bash
# 10. 部署并配置 PackMarketplace (依赖: ReferralV2, UserBalanceManager)
npx hardhat run scripts/deploy-and-setup-PackMarketplace.ts --network <network>

# 11. 部署 FoodMarketplace (依赖: UserBalanceManager)
npx hardhat run scripts/deploy-food-marketplace.ts --network <network>
```

### 阶段 6: 系统集成配置 ⭐ **必须执行**
```bash
# 12. 配置 UserBalanceManager 集成 (配置所有合约间的授权关系)
npx hardhat run scripts/setup-UserBalanceManager-integration.ts --network <network>
```

### 阶段 7: 部署验证和测试
```bash
# 13. 可选：运行部署验证脚本
npx hardhat run scripts/verify-deployment.ts --network <network>
```

## 📊 依赖关系图

```
阶段1: 基础设施
DUST (独立) ──┐
              ├─→ ConfigCenter (独立) ──┐
              └─→ UserBalanceManager (独立) ──┐
                                              │
阶段2: 推荐系统核心                            │
ReferralV2 ← DUST ──┐                        │
   ↓                │                        │
GoldDXP, SilverDXP ─┘                        │
                                             │
阶段3: NFT 系统                              │
CharacterNFTSale ← ConfigCenter, ReferralV2 ─┘
   ↓                                         │
CharacterNFT                                │
   ↓                                         │
BlackGhostSale (独立或已存在)                │
   ↓                                         │
BlackGhostNFT                               │
                                             │
阶段4: 游戏机制                              │
CharacterUpgrade ← GoldDXP, SilverDXP, CharacterNFT, BlackGhostNFT
   ↓                                         │
CharacterNFTStaking ← CharacterNFT, BlackGhostNFT, ConfigCenter
                                             │
阶段5: 市场系统                              │
PackMarketplace ← ReferralV2, UserBalanceManager ←┘
   ↓
FoodMarketplace ← UserBalanceManager
   ↓
阶段6: 系统集成
UserBalanceManager Integration (配置所有授权关系)
```

## 🔧 各脚本功能说明

### 核心基础设施
- **deploy-DUST.ts**: 部署 DUST ERC20 代币合约
- **deploy-and-setup-configCenter.ts**: 部署配置中心，包含所有系统参数
- **deploy-UserBalanceManager.ts**: 部署统一余额管理合约

### 推荐系统
- **deploy-and-setup-ReferralV2.ts**: 部署推荐系统核心（GoldDXP, SilverDXP, ReferralV2），支持多级推荐奖励

### NFT 系统
- **deploy-and-setup-CharacterNFTSale.ts**: 部署角色 NFT 销售系统
- **deploy-blackghost-sale.ts**: 部署黑幽灵 NFT 销售系统
- **setup-BlackGhostSale-referralV2.ts**: 配置 BlackGhostSale 与 ReferralV2 的集成

### 游戏机制
- **deploy-CharacterUpgrade.ts**: 部署角色升级系统，使用 DXP 代币升级角色
- **deploy-and-setup-CharacterNFTStaking.ts**: 部署角色 NFT 质押挖矿系统

### 市场系统
- **deploy-and-setup-PackMarketplace.ts**: 部署包裹市场（Core + Flex NFT）
- **deploy-food-marketplace.ts**: 部署食物市场系统

### 系统集成
- **setup-UserBalanceManager-integration.ts**: 配置合约间授权关系

## ⚠️ 重要注意事项

### 财政金库配置
- **统一财政金库地址**: `0x888Ce07575185Fe5b148b368634b12B0813e92e7`
- 所有市场合约的收益将汇集到此地址

### 依赖关系要求
1. **ReferralV2 系统**: 必须在 CharacterNFTSale 之前部署（提供 DXP 代币）
2. **CharacterUpgrade**: 必须在 CharacterNFT 和 BlackGhostNFT 部署后才能部署
3. **UserBalanceManager**: 必须在 PackMarketplace 和 FoodMarketplace 之前部署
4. **系统集成**: setup-UserBalanceManager-integration.ts 必须最后运行

### 智能合约存在性检查
- 所有部署脚本都包含智能检查功能
- 如果 NFT 合约已存在，将跳过重新部署并使用现有地址
- 支持增量部署和重复执行

### CharacterUpgrade 系统
- **功能**: 使用 Gold DXP 和 Silver DXP 代币升级角色
- **Gold DXP**: 批量升级，仅限 CharacterNFT 合约的角色
- **Silver DXP**: 单个升级，支持任意角色（CharacterNFT 或 BlackGhostNFT）
- **权限**: 自动配置 DXP 代币的销毁权限

### UserBalanceManager 集成要求
1. **部署顺序严格**: UserBalanceManager 必须在市场合约之前部署
2. **授权配置**: 必须运行 setup-UserBalanceManager-integration.ts 来配置合约间的授权关系
3. **关键步骤**: 此集成步骤是整个系统正常运行的前提，不可跳过