# JSON 格式化功能

## 功能概述

JSON 格式化工具提供了多种JSON数据处理功能，帮助开发者快速处理和转换JSON数据。

## 功能特性

### 1. 格式化
将压缩的JSON字符串格式化为易读的格式，支持自定义缩进。

**示例：**
```json
// 输入
{"name":"John","age":30,"city":"New York"}

// 输出
{
  "name": "John",
  "age": 30,
  "city": "New York"
}
```

### 2. 压缩
将格式化的JSON字符串压缩为单行，减少数据传输大小。

**示例：**
```json
// 输入
{
  "name": "John",
  "age": 30
}

// 输出
{"name":"John","age":30}
```

### 3. 转义
将JSON字符串进行转义，用于在代码中嵌入JSON。

**示例：**
```json
// 输入
{"key": "value"}

// 输出
"{\"key\": \"value\"}"
```

### 4. 反转义
将转义的JSON字符串还原。

**示例：**
```json
// 输入
"{\"key\": \"value\"}"

// 输出
{"key": "value"}
```

### 5. 转Dart Map
将JSON转换为Dart Map代码。

**示例：**
```dart
// 输入
{"name": "John", "age": 30}

// 输出
{
  'name': 'John',
  'age': 30,
}
```

### 6. 转TypeScript接口
根据JSON结构生成TypeScript接口定义。

**示例：**
```typescript
// 输入
{"name": "John", "age": 30}

// 输出
interface RootObject {
  name: string;
  age: number;
}
```

## 快捷操作

| 操作 | 说明 |
|------|------|
| 执行 | 处理输入内容 |
| 交换 | 交换输入和输出内容 |
| 复制 | 复制输出内容到剪贴板 |
| 清空 | 清空所有内容 |

## 使用场景

1. **API调试**：格式化API响应数据
2. **数据处理**：压缩JSON以减少传输大小
3. **代码生成**：将JSON转换为Dart或TypeScript代码
4. **数据验证**：检查JSON格式是否正确

## 技术实现

- 使用Dart内置的`dart:convert`库进行JSON处理
- 支持UTF-8编码
- 实时验证JSON格式
- 错误提示和高亮
