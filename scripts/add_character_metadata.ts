import * as hre from 'hardhat';
import { ethers, network } from 'hardhat';
import { vars } from 'hardhat/config';
import { ContractAddressManager } from './utils/ContractAddressManager';

// 定义模板供应量
const templateSupplies: { [key: string]: number } = {
  '1.json': 40,
  '2.json': 10,
  '3.json': 40,
  '4.json': 40,
  '5.json': 40,
  '6.json': 40,
  '7.json': 10,
  '8.json': 40,
  '9.json': 40,
  '10.json': 40,
  '11.json': 40,
  '12.json': 10,
  '13.json': 40,
  '14.json': 40,
  '15.json': 40,
  '16.json': 40,
  '17.json': 10,
  '18.json': 40,
  '19.json': 40,
  '20.json': 40,
  '21.json': 40,
  '22.json': 10,
  '23.json': 40,
  '24.json': 40,
  '25.json': 40,
  '26.json': 40,
  '27.json': 10,
  '28.json': 40,
  '29.json': 40,
  '30.json': 40,
  '31.json': 40,
  '32.json': 10,
  '33.json': 40,
  '34.json': 40,
  '35.json': 40,
  '36.json': 40,
  '37.json': 10,
  '38.json': 40,
  '39.json': 40,
  '40.json': 40,
  '41.json': 40,
  '42.json': 10,
  '43.json': 40,
  '44.json': 40,
  '45.json': 40,
  '46.json': 40,
  '47.json': 10,
  '48.json': 40,
  '49.json': 40,
  '50.json': 40,
  '51.json': 40,
  '52.json': 10,
  '53.json': 40,
  '54.json': 40,
  '55.json': 40,
  '56.json': 40,
  '57.json': 10,
  '58.json': 40,
  '59.json': 40,
  '60.json': 40,
  '61.json': 80,
  '62.json': 17,
  '63.json': 80,
  '64.json': 80,
  '65.json': 80,
  '66.json': 80,
  '67.json': 17,
  '68.json': 80,
  '69.json': 80,
  '70.json': 80,
  '71.json': 80,
  '72.json': 17,
  '73.json': 80,
  '74.json': 80,
  '75.json': 80,
  '76.json': 80,
  '77.json': 17,
  '78.json': 80,
  '79.json': 80,
  '80.json': 80,
  '81.json': 80,
  '82.json': 18,
  '83.json': 80,
  '84.json': 80,
  '85.json': 80,
  '86.json': 80,
  '87.json': 18,
  '88.json': 80,
  '89.json': 80,
  '90.json': 80,
  '91.json': 80,
  '92.json': 17,
  '93.json': 80,
  '94.json': 80,
  '95.json': 80,
  '96.json': 80,
  '97.json': 17,
  '98.json': 80,
  '99.json': 80,
  '100.json': 80,
  '101.json': 80,
  '102.json': 17,
  '103.json': 80,
  '104.json': 80,
  '105.json': 80,
  '106.json': 80,
  '107.json': 17,
  '108.json': 80,
  '109.json': 80,
  '110.json': 80,
  '111.json': 80,
  '112.json': 18,
  '113.json': 80,
  '114.json': 80,
  '115.json': 80,
  '116.json': 80,
  '117.json': 18,
  '118.json': 80,
  '119.json': 80,
  '120.json': 80,
  '121.json': 120,
  '122.json': 40,
  '123.json': 120,
  '124.json': 40,
  '125.json': 120,
  '126.json': 120,
  '127.json': 120,
  '128.json': 40,
  '129.json': 120,
  '130.json': 40,
  '131.json': 120,
  '132.json': 120,
  '133.json': 120,
  '134.json': 40,
  '135.json': 120,
  '136.json': 40,
  '137.json': 120,
  '138.json': 120,
  '139.json': 120,
  '140.json': 40,
  '141.json': 120,
  '142.json': 40,
  '143.json': 120,
  '144.json': 120,
  '145.json': 120,
  '146.json': 40,
  '147.json': 120,
  '148.json': 40,
  '149.json': 120,
  '150.json': 120,
};

const characterNameToId: Record<string, number> = {
  'Airdrop Andy': 1,
  'Scammed Steve': 2,
  'Dustbag Danny': 3,
  'Leverage Larry': 4,
  'Trenches Ghost': 5,
};

const rarityNameToId: Record<string, number> = {
  C: 1,
  R: 2,
  RR: 3,
  SR: 4,
  SSR: 5,
};

function calculateTotalSupply(): number {
  let total = 0;
  for (const [_, supply] of Object.entries(templateSupplies)) {
    total += supply;
  }
  return total;
}

function chunkArray<T>(array: T[], chunkSize: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < array.length; i += chunkSize) {
    chunks.push(array.slice(i, i + chunkSize));
  }
  return chunks;
}

async function main() {
  const addressManager = new ContractAddressManager();
  const networkName = network.name;
  console.log(`开始设置 CharacterNFT 元数据 URI 在 ${networkName} 网络...`);

  try {
    const provider = ethers.provider;

    const signer = new ethers.Wallet(vars.get('PRIVATE_KEY'), provider);
    console.log(`使用地址: ${signer.address}`);

    const characterNFTInfo = addressManager.getContractAddress(networkName, 'CharacterNFT');

    if (!characterNFTInfo) {
      console.error('❌ 无法找到 CharacterNFT 合约地址，请先运行部署脚本');
      process.exit(1);
    }

    const characterNFTArtifact = await hre.artifacts.readArtifact('CharacterNFT');
    const characterNFT = new ethers.Contract(characterNFTInfo.address, characterNFTArtifact.abi, signer);
    console.log('已连接到 CharacterNFT:', characterNFTInfo.address);

    console.log('设置 CharacterNFT 的基础 URI...');
    const metadataURI = 'https://storage.googleapis.com/hungrydegens/metadata/';

    const maxRetries = 3;
    let retries = 0;
    let success = false;

    // 设置 CharacterNFT 的基础 URI
    while (retries < maxRetries && !success) {
      try {
        const tx = await characterNFT.setBaseURI(metadataURI);
        console.log(`交易已提交，等待确认... 交易哈希: ${tx.hash}`);
        await tx.wait();
        console.log(`✅ CharacterNFT 基础 URI 已设置为: ${metadataURI}`);
        success = true;
      } catch (error: unknown) {
        retries++;
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.warn(`尝试 ${retries}/${maxRetries} 失败: ${errorMessage}`);

        if (retries >= maxRetries) {
          throw new Error(`无法设置基础 URI，达到最大重试次数: ${errorMessage}`);
        }

        console.log(`等待 3 秒后重试...`);
        await new Promise((resolve) => setTimeout(resolve, 3000));
      }
    }

    // 保存配置信息
    addressManager.saveContractAddress(networkName, 'CharacterNFTMetadata', characterNFTInfo.address, {
      metadataURI: metadataURI,
      setAt: new Date().toISOString(),
      note: 'CharacterNFT base URI configuration'
    });

    console.log('\n✅ CharacterNFT 元数据 URI 设置完成!');
    console.log(`CharacterNFT 地址: ${characterNFTInfo.address}`);
    console.log(`基础 URI: ${metadataURI}`);
    console.log(`元数据 URL 示例: ${metadataURI}1.json`);

  } catch (error) {
    console.error('❌ 设置元数据过程中发生错误:', error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('CharacterNFT 元数据设置脚本执行失败:', error);
    process.exit(1);
  });
