<template>
  <div>
    <!-- Stat Cards -->
    <n-grid :cols="4" :x-gap="16" :y-gap="16" style="margin-bottom:20px" responsive="screen" item-responsive>
      <n-gi span="4 m:2 l:1">
        <n-card size="small">
          <n-statistic label="本月收入" :value="stats.income" prefix="¥">
            <template #suffix><n-text type="success" style="font-size:12px">{{ stats.incomeChange }}</n-text></template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi span="4 m:2 l:1">
        <n-card size="small">
          <n-statistic label="本月支出" :value="stats.expense" prefix="¥">
            <template #suffix><n-text type="error" style="font-size:12px">{{ stats.expenseChange }}</n-text></template>
          </n-statistic>
        </n-card>
      </n-gi>
      <n-gi span="4 m:2 l:1">
        <n-card size="small">
          <n-statistic label="本月结余" :value="stats.balance" prefix="¥" />
        </n-card>
      </n-gi>
      <n-gi span="4 m:2 l:1">
        <n-card size="small">
          <n-statistic label="本月笔数" :value="stats.recordsCount" />
        </n-card>
      </n-gi>
    </n-grid>

    <!-- Category Pie & Member Comparison (no echarts dependency - pure naive-ui) -->
    <n-grid :cols="2" :x-gap="16" :y-gap="16" responsive="screen" item-responsive>
      <n-gi span="2 m:1">
        <n-card title="支出分类占比" size="small">
          <div v-if="stats.categories && stats.categories.length">
            <div v-for="(cat, i) in stats.categories" :key="cat.category_id" style="margin-bottom:10px">
              <n-space justify="space-between" align="center" style="margin-bottom:4px">
                <span>{{ cat.category_name }}</span>
                <n-text>¥{{ Number(cat.amount).toFixed(2) }} ({{ cat.ratio }})</n-text>
              </n-space>
              <n-progress type="line" :percentage="parseFloat(cat.ratio)" :show-indicator="false" :color="categoryColors[i % categoryColors.length]" />
            </div>
          </div>
          <n-empty v-else description="暂无分类数据" />
        </n-card>
      </n-gi>
      <n-gi span="2 m:1">
        <n-card title="成员消费对比" size="small">
          <div v-if="memberStats.length">
            <div v-for="m in memberStats" :key="m.member" style="margin-bottom:16px">
              <n-card embedded size="small">
                <n-space justify="space-between" align="center">
                  <span style="font-weight:600">{{ m.member }}</span>
                  <n-text type="error" style="font-size:18px;font-weight:700">¥{{ Number(m.expense).toFixed(2) }}</n-text>
                </n-space>
                <n-progress type="line" :percentage="m.percentage" :show-indicator="false" status="error" style="margin-top:8px" />
                <n-space justify="space-between" style="margin-top:4px;font-size:12px;color:#999">
                  <span>{{ m.percentage.toFixed(0) }}% 占比</span>
                  <span>{{ m.records_count }}笔</span>
                </n-space>
              </n-card>
            </div>
          </div>
          <n-empty v-else description="暂无成员数据" />
        </n-card>
      </n-gi>
    </n-grid>

    <!-- Recent Records -->
    <n-card title="最近记录" size="small" style="margin-top:16px">
      <template #header-extra><n-button text @click="$router.push('/records')">查看全部 →</n-button></template>
      <n-data-table :columns="recentColumns" :data="recentRecords" :bordered="false" size="small" />
      <n-empty v-if="!recentRecords.length" description="暂无记录" />
    </n-card>
  </div>
</template>

<script setup>
import { ref, onMounted, h } from 'vue'
import { NTag, NText } from 'naive-ui'
import { getMonthlyStats, getStatsByMember, getRecords } from '../api'

const stats = ref({
  income: 0, expense: 0, balance: 0, recordsCount: 0,
  incomeChange: '', expenseChange: '', categories: []
})
const memberStats = ref([])
const recentRecords = ref([])
const categoryColors = ['#d03050', '#2080f0', '#f0a020', '#8a2be2', '#18a058', '#999']

const recentColumns = [
  { title: '时间', key: 'record_time', width: 140, render: (row) => row.record_time ? row.record_time.slice(5, 16) : '-' },
  {
    title: '类型', key: 'type', width: 70,
    render: (row) => h(NTag, { type: row.type === 'income' ? 'success' : 'error', size: 'small' }, { default: () => row.type === 'income' ? '收入' : '支出' })
  },
  {
    title: '分类', key: 'category', width: 80,
    render: (row) => {
      const cat = row.category
      return cat ? `${cat.icon || ''} ${cat.name || ''}` : '-'
    }
  },
  {
    title: '金额', key: 'amount', width: 100,
    render: (row) => h(NText, { type: row.type === 'income' ? 'success' : 'error', strong: true }, { default: () => `¥${Number(row.amount).toFixed(2)}` })
  },
  { title: '成员', key: 'member', width: 70 },
  { title: '备注', key: 'note', ellipsis: { tooltip: true } },
  {
    title: '来源', key: 'source', width: 70,
    render: (row) => h(NTag, { type: row.source === 'ocr' ? 'info' : 'default', size: 'small' }, { default: () => row.source === 'ocr' ? 'OCR' : '手动' })
  },
]

const loadData = async () => {
  try {
    const now = new Date()
    const month = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`

    const [monthlyRes, memberRes, recordsRes] = await Promise.all([
      getMonthlyStats({ month }).catch(() => ({ income: 0, expense: 0, balance: 0, records_count: 0, categories: [], compare: { mom: {} } })),
      getStatsByMember({ month }).catch(() => ({ data: [] })),
      getRecords({ page_size: 5 }).catch(() => ({ data: [], pagination: { total: 0 } })),
    ])

    stats.value = {
      income: monthlyRes.income || 0,
      expense: monthlyRes.expense || 0,
      balance: monthlyRes.balance || 0,
      recordsCount: monthlyRes.records_count || 0,
      incomeChange: monthlyRes.compare?.mom?.income_change || '0%',
      expenseChange: monthlyRes.compare?.mom?.expense_change || '0%',
      categories: monthlyRes.categories || [],
    }

    const totalExpense = (memberRes.data || []).reduce((s, m) => s + m.expense, 0) || 1
    memberStats.value = (memberRes.data || []).map(m => ({
      ...m,
      percentage: (m.expense / totalExpense) * 100,
    }))

    recentRecords.value = recordsRes.data || []
  } catch (e) {
    console.error('Dashboard load failed:', e)
  }
}

onMounted(loadData)
</script>
