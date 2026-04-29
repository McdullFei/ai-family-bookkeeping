<template>
  <n-card size="small">
    <n-space vertical :size="16">
      <!-- Filters -->
      <n-space wrap>
        <n-select v-model:value="filters.type" :options="typeOptions" placeholder="全部类型" clearable style="width:120px" />
        <n-select v-model:value="filters.member" :options="memberOptions" placeholder="全部成员" clearable style="width:120px" />
        <n-select v-model:value="filters.category_id" :options="categoryOptions" placeholder="全部分类" clearable style="width:140px" />
        <n-select v-model:value="filters.source" :options="sourceOptions" placeholder="全部来源" clearable style="width:120px" />
        <n-date-picker v-model:value="filters.dateRange" type="daterange" clearable />
        <n-input v-model:value="filters.keyword" placeholder="搜索备注..." clearable style="width:160px" />
        <n-button @click="loadData">查询</n-button>
        <n-button type="primary" @click="showExport">导出CSV</n-button>
      </n-space>

      <!-- Table -->
      <n-data-table
        :columns="columns"
        :data="records"
        :bordered="false"
        :loading="loading"
        :pagination="pagination"
        :row-key="r => r.id"
        @update:page="handlePageChange"
      />
    </n-space>
  </n-card>

  <!-- Edit Modal -->
  <n-modal v-model:show="editModal" preset="dialog" title="编辑记录" positive-text="保存" negative-text="取消"
    @positive-click="handleSave">
    <n-form :model="editForm" label-placement="left" label-width="80">
      <n-form-item label="金额"><n-input-number v-model:value="editForm.amount" :precision="2" style="width:100%" /></n-form-item>
      <n-form-item label="类型">
        <n-radio-group v-model:value="editForm.type">
          <n-radio value="expense">支出</n-radio>
          <n-radio value="income">收入</n-radio>
        </n-radio-group>
      </n-form-item>
      <n-form-item label="分类"><n-select v-model:value="editForm.category_id" :options="categoryOptions" /></n-form-item>
      <n-form-item label="成员"><n-input v-model:value="editForm.member" /></n-form-item>
      <n-form-item label="备注"><n-input v-model:value="editForm.note" /></n-form-item>
    </n-form>
  </n-modal>
</template>

<script setup>
import { ref, onMounted, h } from 'vue'
import { NTag, NText, NButton, NSpace, useMessage, useDialog } from 'naive-ui'
import { getRecords, updateRecord, deleteRecord, getCategories, getMembers } from '../api'

const message = useMessage()
const dialog = useDialog()
const loading = ref(false)
const records = ref([])
const editModal = ref(false)
const editForm = ref({})
const categories = ref([])
const members = ref([])

const filters = ref({ type: null, member: null, category_id: null, source: null, dateRange: null, keyword: '' })
const pagination = ref({ page: 1, pageSize: 20, itemCount: 0, showSizePicker: false })

const typeOptions = [
  { label: '收入', value: 'income' },
  { label: '支出', value: 'expense' },
]
const sourceOptions = [
  { label: 'OCR', value: 'ocr' },
  { label: '手动', value: 'manual' },
]
const memberOptions = ref([])
const categoryOptions = ref([])

const columns = [
  { title: 'ID', key: 'id', width: 60 },
  {
    title: '时间', key: 'record_time', width: 140,
    render: (row) => {
      const t = row.record_time
      return t ? t.slice(0, 16).replace('T', ' ') : '-'
    }
  },
  {
    title: '类型', key: 'type', width: 70,
    render: (row) => h(NTag, { type: row.type === 'income' ? 'success' : 'error', size: 'small' }, { default: () => row.type === 'income' ? '收入' : '支出' })
  },
  {
    title: '分类', key: 'category', width: 100,
    render: (row) => {
      const cat = row.category
      return cat ? `${cat.icon || ''} ${cat.name || ''}` : '-'
    }
  },
  {
    title: '金额', key: 'amount', width: 110,
    render: (row) => h(NText, { type: row.type === 'income' ? 'success' : 'error', strong: true }, { default: () => `¥${Number(row.amount).toFixed(2)}` })
  },
  { title: '成员', key: 'member', width: 70 },
  { title: '备注', key: 'note', ellipsis: { tooltip: true } },
  {
    title: '来源', key: 'source', width: 70,
    render: (row) => h(NTag, { type: row.source === 'ocr' ? 'info' : 'default', size: 'small' }, { default: () => row.source === 'ocr' ? 'OCR' : '手动' })
  },
  {
    title: '操作', key: 'actions', width: 140,
    render: (row) => h(NSpace, { size: 'small' }, {
      default: () => [
        h(NButton, { size: 'small', onClick: () => openEdit(row) }, { default: () => '编辑' }),
        h(NButton, { size: 'small', type: 'error', ghost: true, onClick: () => handleDelete(row) }, { default: () => '删除' }),
      ]
    }),
  },
]

const loadData = async () => {
  loading.value = true
  try {
    const params = { page: pagination.value.page, page_size: pagination.value.pageSize }
    if (filters.value.type) params.type = filters.value.type
    if (filters.value.member) params.member = filters.value.member
    if (filters.value.category_id) params.category_id = filters.value.category_id
    if (filters.value.source) params.source = filters.value.source
    if (filters.value.keyword) params.note_like = filters.value.keyword
    if (filters.value.dateRange && filters.value.dateRange[0] && filters.value.dateRange[1]) {
      params.start_date = new Date(filters.value.dateRange[0]).toISOString().slice(0, 10)
      params.end_date = new Date(filters.value.dateRange[1]).toISOString().slice(0, 10)
    }

    const res = await getRecords(params)
    records.value = res.data || []
    pagination.value.itemCount = res.pagination?.total || 0
  } catch (e) {
    message.error('加载失败: ' + (e.error || e.message || '未知错误'))
  } finally {
    loading.value = false
  }
}

const handlePageChange = (page) => {
  pagination.value.page = page
  loadData()
}

const openEdit = (row) => {
  editForm.value = { ...row }
  editModal.value = true
}

const handleSave = async () => {
  try {
    await updateRecord(editForm.value.id, editForm.value)
    message.success('保存成功')
    loadData()
  } catch (e) {
    message.error('保存失败')
  }
}

const handleDelete = (row) => {
  dialog.warning({
    title: '确认删除',
    content: `确定删除这笔 ¥${row.amount} 的${row.type === 'income' ? '收入' : '支出'}记录？`,
    positiveText: '删除',
    negativeText: '取消',
    onPositiveClick: async () => {
      try {
        await deleteRecord(row.id)
        message.success('已删除')
        loadData()
      } catch (e) {
        message.error('删除失败')
      }
    },
  })
}

const showExport = () => {
  message.info('导出功能开发中')
}

const loadMeta = async () => {
  try {
    const [catRes, memRes] = await Promise.all([getCategories(), getMembers()])
    categories.value = catRes.data || []
    members.value = memRes.data || []
    categoryOptions.value = categories.value.map(c => ({ label: `${c.icon} ${c.name}`, value: c.id }))
    memberOptions.value = members.value.map(m => ({ label: m.name, value: m.name }))
  } catch (e) { /* ignore */ }
}

onMounted(() => { loadData(); loadMeta() })
</script>
