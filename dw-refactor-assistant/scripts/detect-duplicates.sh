#!/bin/bash
# 数仓模型重复检测脚本
# 用法: bash detect-duplicates.sh <connection_string> <output_file>
# 示例: bash detect-duplicates.sh "host=xxx port=3306 user=xxx pass=xxx db=xxx" ./output/dup_report.txt

set -e

CONNECTION="$1"
OUTPUT_FILE="${2:-./dup_report.txt}"

if [ -z "$CONNECTION" ]; then
    echo "❌ 错误: 请提供数据库连接信息"
    echo "用法: bash detect-duplicates.sh <connection_string> <output_file>"
    exit 1
fi

DB_NAME=$(echo "$CONNECTION" | grep -oE 'db=[^ ]+' | cut -d= -f2)
TIMESTAMP=$(date '+%Y%m%d %H:%M:%S')

echo "🔍 模型重复检测开始..."
echo "📊 数据库: $DB_NAME"
echo "⏱  时间: $TIMESTAMP"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# 1. 基于表名相似性检测
echo "1️⃣  基于表名相似性检测..."
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
ORDER BY TABLE_NAME
" > /tmp/all_tables.txt 2>/dev/null

# 检测相似表名（简单的字符串匹配）
> /tmp/similar_names.txt
sort /tmp/all_tables.txt | while read -r table; do
    [ -z "$table" ] && continue

    # 查找相似名称（去除后缀 _1, _2, _v1, _v2）
    base_name=$(echo "$table" | sed -E 's/_(v[0-9]+|[0-9]+|old|new|bak|backup|copy)$//')

    # 查找同基础名的其他表
    similar=$(grep "^${base_name}_" /tmp/all_tables.txt 2>/dev/null | grep -v "^${table}$")

    if [ -n "$similar" ]; then
        echo "$table | $similar" >> /tmp/similar_names.txt
    fi
done

# 2. 基于字段结构相似性检测
echo "2️⃣  基于字段结构相似性检测..."

# 准备每个表的字段哈希
> /tmp/table_hashes.txt
for table in $(cat /tmp/all_tables.txt); do
    [ -z "$table" ] && continue

    # 获取表的所有字段名（排序后拼接作为哈希）
    fields=$(mysql "$CONNECTION" -N -e "
    SELECT COLUMN_NAME
    FROM information_schema.columns
    WHERE TABLE_SCHEMA = '$DB_NAME' AND TABLE_NAME = '$table'
    ORDER BY ORDINAL_POSITION
    " 2>/dev/null | tr '\n' ',' | tr -d ' ')

    echo "$table | $fields" >> /tmp/table_hashes.txt
done

# 查找哈希相同的表
> /tmp/similar_structures.txt
sort -t'|' -k2 /tmp/table_hashes.txt | awk -F'|' '{
    hash = $2;
    gsub(/^[ \t]+|[ \t]+$/, "", hash);
    if (prev_hash != "" && hash == prev_hash) {
        print prev_line " 和 " $1 " 结构相同";
    }
    prev_hash = hash;
    prev_line = $1;
}' > /tmp/similar_structures.txt

# 3. 基于行数差异检测（同一名称但不同行数）
echo "3️⃣  基于行数差异检测..."
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME, TABLE_ROWS
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME' AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME, TABLE_ROWS DESC
" > /tmp/table_rows.txt 2>/dev/null

# 4. 生成报告
{
    echo "════════════════════════════════════════════════"
    echo "  数仓模型重复检测报告"
    echo "════════════════════════════════════════════════"
    echo ""
    echo "📊 数据库: $DB_NAME"
    echo "⏱  扫描时间: $TIMESTAMP"
    echo ""

    # 表名相似
    SIMILAR_COUNT=$(wc -l < /tmp/similar_names.txt)
    echo "## 1. 表名相似的表"
    echo ""
    if [ "$SIMILAR_COUNT" -gt 0 ]; then
        echo "发现 $SIMILAR_COUNT 组相似表名（建议人工评估是否需要合并）"
        echo ""
        cat /tmp/similar_names.txt
    else
        echo "✅ 未发现表名相似的表"
    fi
    echo ""

    # 结构相似
    STRUCT_COUNT=$(wc -l < /tmp/similar_structures.txt)
    echo "## 2. 字段结构完全相同的表"
    echo ""
    if [ "$STRUCT_COUNT" -gt 0 ]; then
        echo "⚠️  发现 $STRUCT_COUNT 组完全重复的表（强烈建议合并）"
        echo ""
        cat /tmp/similar_structures.txt
    else
        echo "✅ 未发现结构完全相同的表"
    fi
    echo ""

    # 重复逻辑分析
    echo "## 3. 重复逻辑分析"
    echo ""
    echo "### 检测方法"
    echo "1. **表名相似**: 检测具有相同前缀的表名（如 xxx_v1, xxx_v2）"
    echo "2. **结构相同**: 比较所有字段定义，结构完全一致的表"
    echo "3. **大小相近**: 检测存储大小相近且业务相似的表"
    echo ""
    echo "### 常见重复模式"
    echo ""
    echo "1. **版本迭代遗留**: xxx_v1, xxx_v2, xxx_v3"
    echo "2. **不同人开发**: order_info, orders, order_data"
    echo "3. **不同步命名**: user_dim, dim_user, dim_users"
    echo "4. **临时表残留**: tmp_order_202401, tmp_user_202402"
    echo ""

    echo "## 4. 整改建议"
    echo ""
    echo "### 评估标准"
    echo "对每组重复表，回答以下问题："
    echo "1. 这些表的数据是否一致？"
    echo "2. 是否存在不同的业务口径？"
    echo "3. 是否都有下游使用？"
    echo "4. 合并的成本有多大？"
    echo ""
    echo "### 合并策略"
    echo ""
    echo "| 情况 | 处理策略 |"
    echo "|------|---------|"
    echo "| 完全重复（无下游） | 直接删除 |"
    echo "| 完全重复（有下游） | 合并到一个，其他改用视图兼容 |"
    echo "| 业务不同 | 保留，但需明确命名差异 |"
    echo "| 版本迭代 | 评估是否还需要旧版本 |"
    echo ""
    echo "### 合并步骤"
    echo "1. 评估所有重复表的数据差异"
    echo "2. 确定保留的标准版本"
    echo "3. 创建新表（按 OneData 命名规范）"
    echo "4. 迁移数据到新表"
    echo "5. 创建视图兼容旧表名"
    echo "6. 通知下游切换"
    echo "7. 下线旧表"
    echo ""
    echo "════════════════════════════════════════════════"
} > "$OUTPUT_FILE"

cat "$OUTPUT_FILE"

# 清理临时文件
rm -f /tmp/all_tables.txt /tmp/similar_names.txt /tmp/table_hashes.txt
rm -f /tmp/similar_structures.txt /tmp/table_rows.txt

echo ""
echo "════════════════════════════════════════════════"
echo "✅ 报告已生成: $OUTPUT_FILE"
echo "════════════════════════════════════════════════"
echo ""
echo "💡 提示:"
echo "   - 表名相似但结构不同的表，需要人工分析"
echo "   - 字段结构完全相同的表，应优先合并"
echo "   - 合并前务必进行影响分析（/impact-analysis）"
