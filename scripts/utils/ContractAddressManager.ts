// utils/ContractAddressManager.ts
import * as fs from 'fs';
import * as path from 'path';

/**
 * 合约地址管理器，用于保存和读取部署到各网络的合约地址
 */
export class ContractAddressManager {
  private readonly deployedDir: string;

  /**
   * 构造函数
   * @param baseDir 基础目录，默认为项目根目录下的deployed文件夹
   */
  constructor(baseDir: string = 'deployed') {
    this.deployedDir = path.resolve(process.cwd(), baseDir);
    this.ensureDirectoryExists(this.deployedDir);
  }

  /**
   * 保存合约地址
   * @param network 网络名称
   * @param contractName 合约名称
   * @param address 合约地址
   * @param additionalInfo 额外信息 (可选)
   */
  public saveContractAddress(
    network: string,
    contractName: string,
    address: string,
    additionalInfo: Record<string, any> = {}
  ): void {
    // 确保网络目录存在
    const networkDir = path.join(this.deployedDir, network);
    this.ensureDirectoryExists(networkDir);

    // 构建数据对象
    const data = {
      address,
      deployedAt: new Date().toISOString(),
      ...additionalInfo,
    };

    // 保存到文件
    const filePath = path.join(networkDir, `${contractName}.json`);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));

    console.log(`✅ 已保存合约 ${contractName} 地址到 ${filePath}`);
  }

  /**
   * 读取合约地址
   * @param network 网络名称
   * @param contractName 合约名称
   * @returns 合约地址信息，如果不存在则返回null
   */
  public getContractAddress(network: string, contractName: string): { address: string; [key: string]: any } | null {
    const filePath = path.join(this.deployedDir, network, `${contractName}.json`);

    if (!fs.existsSync(filePath)) {
      console.warn(`⚠️ 合约 ${contractName} 在网络 ${network} 上的地址文件不存在`);
      return null;
    }

    try {
      const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
      return data;
    } catch (error) {
      console.error(`❌ 读取合约 ${contractName} 地址时出错:`, error);
      return null;
    }
  }

  /**
   * 获取指定网络上所有合约的地址
   * @param network 网络名称
   * @returns 合约名称到地址的映射
   */
  public getAllContractAddresses(network: string): Record<string, string> | null {
    const networkDir = path.join(this.deployedDir, network);

    if (!fs.existsSync(networkDir)) {
      console.warn(`⚠️ 网络 ${network} 的部署目录不存在`);
      return null;
    }

    try {
      const files = fs.readdirSync(networkDir);
      const contracts: Record<string, string> = {};

      for (const file of files) {
        if (file.endsWith('.json')) {
          const contractName = path.basename(file, '.json');
          const data = JSON.parse(fs.readFileSync(path.join(networkDir, file), 'utf8'));
          contracts[contractName] = data.address;
        }
      }

      return contracts;
    } catch (error) {
      console.error(`❌ 读取网络 ${network} 上的合约地址时出错:`, error);
      return null;
    }
  }

  /**
   * 确保目录存在，如果不存在则创建
   * @param dir 目录路径
   */
  private ensureDirectoryExists(dir: string): void {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  }
}
