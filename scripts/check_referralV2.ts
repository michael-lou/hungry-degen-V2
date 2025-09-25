import * as fs from 'fs';
import { ethers } from 'hardhat';
import path from 'path';

// 读取部署信息
function getDeployedInfo(name: string) {
  const file = path.join(__dirname, `../deployed/baseSepolia/${name}.json`);
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// 合约 ABI 路径
const BlackGhostSaleABI = require('../abi/BlackGhostSale.json');
const CharacterNFTSaleABI = require('../abi/CharacterNFTSale.json');
const FoodMarketplaceABI = require('../abi/FoodMarketplace.json');

async function main() {
  // 读取部署信息
  const blackGhostSaleInfo = getDeployedInfo('BlackGhostSale');
  const characterNFTSaleInfo = getDeployedInfo('CharacterNFTSale');
  const foodMarketplaceInfo = getDeployedInfo('FoodMarketplace');

  // 合约实例
  const blackGhostSale = new ethers.Contract(blackGhostSaleInfo.address, BlackGhostSaleABI, (ethers as any).provider);
  const characterNFTSale = new ethers.Contract(
    characterNFTSaleInfo.address,
    CharacterNFTSaleABI,
    (ethers as any).provider
  );
  const foodMarketplace = new ethers.Contract(
    foodMarketplaceInfo.address,
    FoodMarketplaceABI,
    (ethers as any).provider
  );

  // 查询 referralV2
  const blackGhostSaleReferral = await blackGhostSale.referralV2();
  const characterNFTSaleReferral = await characterNFTSale.referralV2();
  const foodMarketplaceReferral = await foodMarketplace.referralV2();

  console.log('BlackGhostSale.referralV2:', blackGhostSaleReferral);
  console.log('CharacterNFTSale.referralV2:', characterNFTSaleReferral);
  console.log('FoodMarketplace.referralV2:', foodMarketplaceReferral);

  // 你可以在这里补充对比预期值的逻辑
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
