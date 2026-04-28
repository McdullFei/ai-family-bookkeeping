import axios from 'axios'

const api = axios.create({
  baseURL: '/api',
  timeout: 15000,
})

// Request interceptor - attach JWT token
api.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// Response interceptor - handle 401
api.interceptors.response.use(
  res => res.data,
  err => {
    if (err.response?.status === 401) {
      localStorage.removeItem('token')
      window.location.hash = '#/login'
    }
    return Promise.reject(err.response?.data || err)
  }
)

// Auth
export const login = (data) => api.post('/auth/login', data)

// Records
export const createRecord = (data) => api.post('/records', data)
export const getRecords = (params) => api.get('/records', { params })
export const updateRecord = (id, data) => api.put(`/records/${id}`, data)
export const deleteRecord = (id) => api.delete(`/records/${id}`)

// Categories
export const getCategories = (params) => api.get('/categories', { params })
export const createCategory = (data) => api.post('/categories', data)
export const updateCategory = (id, data) => api.put(`/categories/${id}`, data)
export const deleteCategory = (id) => api.delete(`/categories/${id}`)

// Members
export const getMembers = () => api.get('/members')

// Stats
export const getDailyStats = (params) => api.get('/stats/daily', { params })
export const getWeeklyStats = (params) => api.get('/stats/weekly', { params })
export const getMonthlyStats = (params) => api.get('/stats/monthly', { params })
export const getStatsByMember = (params) => api.get('/stats/by-member', { params })
export const getStatsByCategory = (params) => api.get('/stats/by-category', { params })

export default api
