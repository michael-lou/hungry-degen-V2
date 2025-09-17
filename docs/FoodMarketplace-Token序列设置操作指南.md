# FoodMarketplace Token序列设置操作指南

## 🎯 概述

FoodMarketplace 合约支持设置和重新设置食物开箱的 token 序列。合约提供了两种设置方式：一次性设置和分批设置。

## 📋 操作方法

### 方法一：一次性设置（适用于较小序列）

```javascript
// 直接设置完整的 token 序列
await foodMarketplace.setTokenSequence([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
```

### 方法二：分批设置（适用于大量数据）

```javascript
// 1. 初始化并清空原有序列
await foodMarketplace.initializeTokenSequence(1000); // 预计总长度

// 2. 分批添加 token（可多次调用）
await foodMarketplace.appendTokenSequence([1, 2, 3, ..., 100]);
await foodMarketplace.appendTokenSequence([101, 102, 103, ..., 200]);
// ... 继续分批添加

// 3. 完成设置
await foodMarketplace.finalizeTokenSequence();
```

## 🔄 重新设置序列

### 完全覆盖原有序列
```javascript
// 直接使用 setTokenSequence 即可覆盖
await foodMarketplace.setTokenSequence([新的序列...]);
```

### 分批重新设置
```javascript
// 1. 先初始化（会清空原有序列）
await foodMarketplace.initializeTokenSequence(新的总长度);

// 2. 分批添加新序列
// 3. 完成设置
```

## 📊 查询和监控

### 查看当前序列
```javascript
// 获取完整序列（小心：大序列可能超出查询限制）
const sequence = await foodMarketplace.getTokenSequence();

// 获取当前序列长度
const length = await foodMarketplace.getSequenceProgress();

// 获取当前索引位置
const index = await foodMarketplace.getCurrentSequenceIndex();
```

### 重置索引位置
```javascript
// 将开箱索引重置为 0（从头开始）
await foodMarketplace.resetSequenceIndex();
```