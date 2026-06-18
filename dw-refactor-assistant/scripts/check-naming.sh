#!/bin/bash
# 数仓命名规范检查脚本
# 用法: bash check-naming.sh <connection_string> <output_file>
# 示例: bash check-naming.sh "host=xxx port=3306 user=xxx pass=xxx db=xxx" ./output/naming_report.txt

set -e

CONNECTION="$1"
OUTPUT_FILE="${2:-./naming_report.txt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$CONNECTION" ]; then
    echo "❌ 错误: 请提供数据库连接信息"
    echo "用法: bash check-naming.sh <connection_string> <output_file>"
    exit 1
fi

DB_NAME=$(echo "$CONNECTION" | grep -oE 'db=[^ ]+' | cut -d= -f2)
TIMESTAMP=$(date '+%Y%m%d %H:%M:%S')

echo "🔍 命名规范检查开始..."
echo "📊 数据库: $DB_NAME"
echo "⏱  时间: $TIMESTAMP"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# 1. 表名命名规范检查
echo "1️⃣  检查表名命名规范..."
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME NOT REGEXP '^(ods|dwd|dws|ads|dim)_'
ORDER BY TABLE_NAME
" > /tmp/naming_violations.txt 2>/dev/null

# 2. 临时表检查
echo "2️⃣  检查临时表..."
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME REGEXP '^tmp_'
ORDER BY TABLE_NAME
" > /tmp/temp_tables.txt 2>/dev/null

# 3. 版本号后缀检查
echo "3️⃣  检查版本号后缀..."
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND TABLE_NAME REGEXP '_(v[0-9]+|old|new|bak|backup|copy|test)$'
ORDER BY TABLE_NAME
" > /tmp/versioned_tables.txt 2>/dev/null

# 4. 字段名规范检查
echo "4️⃣  检查字段名规范..."

# 准备表名列表
TABLES=$(mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
ORDER BY TABLE_NAME
" 2>/dev/null)

# 检查每个表的字段名
> /tmp/field_violations.txt
for table in $TABLES; do
    # 检查 PascalCase 字段名（应为 snake_case）
    violations=$(mysql "$CONNECTION" -N -e "
    SELECT COLUMN_NAME
    FROM information_schema.columns
    WHERE TABLE_SCHEMA = '$DB_NAME'
      AND TABLE_NAME = '$table'
      AND COLUMN_NAME REGEXP '[A-Z]'
    " 2>/dev/null)

    if [ -n "$violations" ]; then
        echo "表 $table:" >> /tmp/field_violations.txt
        echo "$violations" | while read col; do
            echo "  字段 $col 包含大写字母" >> /tmp/field_violations.txt
        done
    fi
done

# 5. 注释缺失检查
echo "5️⃣  检查表注释缺失..."
mysql "$CONNECTION" -N -e "
SELECT TABLE_NAME
FROM information_schema.tables
WHERE TABLE_SCHEMA = '$DB_NAME'
  AND (TABLE_COMMENT = '' OR TABLE_COMMENT IS NULL)
ORDER BY TABLE_NAME
" > /tmp/missing_table_comments.txt 2>/dev/null

# 6. 生成报告
{
    echo "════════════════════════════════════════════════"
    echo "  数仓命名规范检查报告"
    echo "════════════════════════════════════════════════"
    echo ""
    echo "📊 数据库: $DB_NAME"
    echo "⏱  扫描时间: $TIMESTAMP"
    echo ""

    # 统计
    TOTAL_TABLES=$(mysql "$CONNECTION" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE TABLE_SCHEMA='$DB_NAME'" 2>/dev/null)
    NAMING_VIOLATIONS=$(wc -l < /tmp/naming_violations.txt)
    TEMP_TABLES=$(wc -l < /tmp/temp_tables.txt)
    VERSIONED_TABLES=$(wc -l < /tmp/versioned_tables.txt)
    FIELD_VIOLATIONS=$(grep -c "字段" /tmp/field_violations.txt 2>/dev/null || echo 0)
    MISSING_COMMENTS=$(wc -l < /tmp/missing_table_comments.txt)

    echo "## 总体统计"
    echo ""
    echo "| 指标 | 数量 |"
    echo "|------|------|"
    echo "| 总表数 | $TOTAL_TABLES |"
    echo "| 命名不规范表 | $NAMING_VIOLATIONS |"
    echo "| 临时表 | $TEMP_TABLES |"
    echo "| 版本号/备份后缀 | $VERSIONED_TABLES |"
    echo "| 字段名不规范 | $FIELD_VIOLATIONS |"
    echo "| 表注释缺失 | $MISSING_COMMENTS |"
    echo ""
    echo "## 1. 表名命名不规范"
    echo ""
    if [ "$NAMING_VIOLATIONS" -gt 0 ]; then
        echo "不符合规范: ods_/dwd_/dws_/ads_/dim_ 前缀"
        echo ""
        cat /tmp/naming_violations.txt
    else
        echo "✅ 无命名不规范表"
    fi
    echo ""

    echo "## 2. 临时表"
    echo ""
    if [ "$TEMP_TABLES" -gt 0 ]; then
        echo "⚠️  发现 $TEMP_TABLES 个临时表（应清理）"
        echo ""
        cat /tmp/temp_tables.txt
    else
        echo "✅ 无临时表"
    fi
    echo ""

    echo "## 3. 版本号/备份后缀表"
    echo ""
    if [ "$VERSIONED_TABLES" -gt 0 ]; then
        echo "⚠️  发现 $VERSIONED_TABLES 个版本/备份表（应通过注释或元数据管理）"
        echo ""
        cat /tmp/versioned_tables.txt
    else
        echo "✅ 无版本/备份后缀表"
    fi
    echo ""

    echo "## 4. 字段命名不规范"
    echo ""
    if [ "$FIELD_VIOLATIONS" -gt 0 ]; then
        echo "⚠️  字段应使用 snake_case 命名"
        echo ""
        cat /tmp/field_violations.txt
    else
        echo "✅ 字段命名规范"
    fi
    echo ""

    echo "## 5. 表注释缺失"
    echo ""
    if [ "$MISSING_COMMENTS" -gt 0 ]; then
        echo "⚠️  发现 $MISSING_COMMENTS 个表无注释"
        echo ""
        cat /tmp/missing_table_comments.txt
    else
        echo "✅ 所有表都有注释"
    fi
    echo ""

    echo "## 整改建议"
    echo ""
    echo "### 优先级 1：清理临时表"
    echo "- tmp_ 前缀的表应评估后清理"
    echo ""
    echo "### 优先级 2：合并版本/备份表"
    echo "- *_v1, *_old, *_bak 等后缀的表应评估后合并或删除"
    echo ""
    echo "### 优先级 3：规范化表名"
    echo "- 按 {layer}_{domain}_{entity} 规范重命名"
    echo "- 同步修改下游引用"
    echo ""
    echo "### 优先级 4：补充注释"
    echo "- 为所有表添加 TBLPROPERTIES 'comment'"
    echo ""
    echo "════════════════════════════════════════════════"
} > "$OUTPUT_FILE"

cat "$OUTPUT_FILE"

# 清理临时文件
rm -f /tmp/naming_violations.txt /tmp/temp_tables.txt /tmp/versioned_tables.txt
rm -f /tmp/field_violations.txt /tmp/missing_table_comments.txt

echo ""
echo "════════════════════════════════════════════════"
echo "✅ 报告已生成: $OUTPUT_FILE"
echo "════════════════════════════════════════════════"
