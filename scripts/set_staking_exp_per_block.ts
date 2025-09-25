import { ethers, network } from 'hardhat';
import { ContractAddressManager } from './utils/ContractAddressManager';
import { EXP_SCALER, fromScaled, toScaled } from './utils/expScaler';

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  const humanTarget = '0.0000000031';
  console.log(`设置 CharacterNFTStaking 的 expPerBlock 到 ${humanTarget} (12位自定义精度) @ ${networkName} ...`);

  // 获取可用签名者（容错处理）
  let deployerAddress = 'unknown';
  let signer: any = undefined;
  try {
    const signers = await ethers.getSigners();
    if (signers && signers.length > 0) {
      signer = signers[0];
      deployerAddress = signer.address;
    }
  } catch {}
  console.log(`操作者地址: ${deployerAddress}`);

  try {
    // 1) 读取地址
    console.log('\n🔍 步骤1: 获取合约地址...');
    const stakingInfo = addressManager.getContractAddress(networkName, 'CharacterNFTStaking');
    if (!stakingInfo?.address) throw new Error('CharacterNFTStaking 合约尚未部署');
    console.log(`CharacterNFTStaking: ${stakingInfo.address}`);

    // 2) 连接合约
    console.log('\n🔗 步骤2: 连接到合约...');
    const StakingFactory = await ethers.getContractFactory('CharacterNFTStaking');
    const staking = StakingFactory.attach(stakingInfo.address).connect(signer ?? (ethers as any).provider) as any;
    console.log('✅ 合约连接成功');

    // 3) 读取当前配置
    console.log('\n🔍 步骤3: 读取当前配置...');
    const cfg = await staking.stakingConfig();
  const currentExpPerBlock = cfg.expPerBlock as bigint; // scaled
    const currentEndBlock = cfg.endBlock as bigint;
    const currentActive = cfg.active as boolean;
  console.log(`当前 expPerBlock (scaled): ${currentExpPerBlock.toString()} (human ~ ${fromScaled(currentExpPerBlock)} )`);
    console.log(`当前 endBlock: ${currentEndBlock.toString()}`);
    console.log(`当前 active: ${currentActive}`);

  // 4) 计算目标 expPerBlock (12 位精度自定义)
  const targetExp = toScaled(humanTarget); // 3.1e-9 * 1e12 = 3100n
  console.log(`目标 expPerBlock scaled: ${targetExp.toString()} (human ${humanTarget})`);

    if (currentExpPerBlock === targetExp) {
      console.log('✅ expPerBlock 已是目标值，无需更新');
    } else {
      if (!signer) throw new Error('未找到可用签名者，无法发送交易。请检查 hardhat.config.ts 的账户配置');
      console.log('\n🔧 步骤4: 调用 updateConfig 更新 expPerBlock...');
  const tx = await staking.connect(signer).updateConfig(targetExp, currentEndBlock, currentActive);
      console.log(`   交易哈希: ${tx.hash}`);
      await tx.wait();
      const after = await staking.stakingConfig();
  console.log(`✅ 更新完成，新 expPerBlock scaled: ${(after.expPerBlock as bigint).toString()} (human ~ ${fromScaled(after.expPerBlock as bigint)})`);
      if ((after.expPerBlock as bigint) !== targetExp) {
        throw new Error('设置后验证失败: expPerBlock 未按预期更新');
      }
    }

    // 5) 保存到地址管理器（附加元信息）
    console.log('\n📝 步骤5: 保存配置信息...');
    try {
      addressManager.saveContractAddress(networkName, 'CharacterNFTStaking', stakingInfo.address, {
        ...(stakingInfo.metadata ? { metadata: stakingInfo.metadata } : {}),
        deployer: deployerAddress,
        deploymentMode: 'upgradeable',
        proxyType: 'UUPS',
        config: {
          ...(stakingInfo.config || {}),
          expPerBlock: targetExp.toString(), // scaled
          expPerBlockHuman: humanTarget,
          expPerBlockScaler: EXP_SCALER.toString(),
          expPerBlockDecimals: 12,
          updatedAt: new Date().toISOString(),
        },
  description: 'CharacterNFTStaking with updated expPerBlock (12-decimal scaled)',
      });
      console.log('✅ 配置信息已保存');
    } catch (e) {
      console.log('⚠️ 保存配置信息时出错:', e);
    }

    console.log('\n✅ CharacterNFTStaking expPerBlock 设置完成!');
    console.log('\n📋 摘要:');
    console.log(`网络: ${networkName}`);
    console.log(`操作者: ${deployerAddress}`);
    console.log(`合约: ${stakingInfo.address}`);
  console.log(`目标 expPerBlock(12): ${humanTarget} -> ${targetExp}`);
  } catch (error) {
    console.error('\n❌ 脚本执行失败:', error);
    process.exit(1);
  }
}

main();
