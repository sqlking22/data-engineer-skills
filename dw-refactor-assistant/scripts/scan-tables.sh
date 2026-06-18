#!/bin/bash
# 数仓表资产扫描脚本
# 用法: bash scan-tables.sh <connection_string> <output_dir>
# 示例: bash scan-tables.sh "host=xxx port=3306 user=xxx pass=xxx db=xxx" ./output

set -e

CONNECTION="$1"
OUTPUT_DIR="${2:-./inventory_output}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$CONNECTION" ]; then
    echo "❌ 错误: 请提供数据库连接信息"
    echo "用法: bash scan-tables.sh <connection_string> <output_dir>"
    echo "示例: bash scan-tables.sh 'host=xxx port=3306 user=xxx pass=xxx db=xxx' ./output"
    exit 1
fi

echo "🔍 数仓资产扫描开始..."
echo "📁 输出目录: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 提取数据库名
DB_NAME=$(echo "$CONNECTION" | grep -oE 'db=[^ ]+' | cut -d= -f2)
if [ -z "$DB_NAME" ]; then
    echo "❌ 错误: 连接信息中未指定数据库"
    exit 1
fi

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_FILE="$OUTPUT_DIR/table_inventory_${DB_NAME}_${TIMESTAMP}.yaml"

echo "📊 扫描数据库: $DB_NAME"
echo "⏱  扫描时间: $(date)"

# 扫描表信息
mysql "$CONNECTION" -N -e "
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE,
    TABLE_ROWS,
    ROUND(DATA_LENGTH / 1024 / 1024 / 1024, 2) AS SIZE_GB,
    TABLE_COMMENT,
    CREATE_TIME,
    UPDATE_TIME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
ORDER BY TABLE_SCHEMA, TABLE_NAME
" > "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null || {
    echo "❌ 错误: 数据库连接失败或查询失败"
    echo "请检查连接信息: $CONNECTION"
    exit 1
}

# 生成 YAML 格式输出
echo "📝 生成 YAML 格式清单..."
cat > "$OUTPUT_FILE" << EOF
# 数仓表资产清单
# 扫描时间: $(date '+%Y-%m-%d %H:%M:%S')
# 数据库: $DB_NAME
inventory_date: "$(date '+%Y-%m-%d')"
scope: "$DB_NAME"
data_source: "ADB MySQL / MySQL"

summary:
  total_tables: $(wc -l < "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt")
  total_size_gb: $(awk '{sum+=$5} END {printf "%.2f", sum}' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt")

by_layer:
  ods: { tables: $(awk -F'\t' '$2 ~ /^ods_/' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null | wc -l) }
  dwd: { tables: $(awk -F'\t' '$2 ~ /^dwd_/' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null | wc -l) }
  dws: { tables: $(awk -F'\t' '$2 ~ /^dws_/' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null | wc -l) }
  ads: { tables: $(awk -F'\t' '$2 ~ /^ads_/' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null | wc -l) }
  dim: { tables: $(awk -F'\t' '$2 ~ /^dim_/' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null | wc -l) }
  unknown: { tables: $(awk -F'\t' '$2 !~ /^(ods|dwd|dws|ads|dim)_/' "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt" 2>/dev/null | wc -l) }
  note: "以上为按命名规范的简单分类，实际归属需结合业务分析"

tables:
EOF

# 添加表详细信息
while IFS=$'\t' read -r schema name type rows size_gb comment create_time update_time; do
    [ -z "$name" ] && continue
    cat >> "$OUTPUT_FILE" << EOF
  - schema: "$schema"
    name: "$name"
    type: "$type"
    layer: "$(echo "$name" | grep -oE '^(ods|dwd|dws|ads|dim)_' || echo "unknown")"
    domain: "待归域"
    size_gb: $size_gb
    row_count: $rows
    has_comment: $([ -n "$comment" ] && echo "true" || echo "false")
    create_time: "$create_time"
    last_modified: "$update_time"

EOF
done < "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt"

# 命名规范检查
echo "🔍 命名规范检查..."
NAMING_ISSUE_FILE="$OUTPUT_DIR/naming_issues_${TIMESTAMP}.txt"
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME, TABLE_COMMENT
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME NOT REGEXP '^(ods|dwd|dws|ads|dim|tmp|backup|bak)_'
  AND TABLE_NAME NOT REGEXP '^_'
ORDER BY TABLE_NAME
" > "$NAMING_ISSUE_FILE" 2>/dev/null

NAMING_VIOLATIONS=$(wc -l < "$NAMING_ISSUE_FILE")
echo "  发现 $NAMING_VIOLATIONS 个命名不规范表"

# 生成摘要
echo ""
echo "════════════════════════════════════════════════"
echo "✅ 扫描完成"
echo "════════════════════════════════════════════════"
echo "📁 清单文件: $OUTPUT_FILE"
echo "📋 原始数据: $OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt"
echo "⚠️  命名问题: $NAMING_ISSUE_FILE ($NAMING_VIOLATIONS 个)"
echo "════════════════════════════════════════════════"

# 清理临时文件
rm -f "$OUTPUT_DIR/tables_raw_${TIMESTAMP}.txt"

echo ""
echo "📖 下一步:"
echo "   1. 查看 $OUTPUT_FILE 了解资产现状"
echo "   2. 查看 $NAMING_ISSUE_FILE 处理命名问题"
echo "   3. 执行 /asset-inventory 生成完整问题报告"
