export const doljabiOptions = [
  { id: 'money', label: '돈', detail: '풍요로운 재물운', color: '#2f9e44' },
  { id: 'thread', label: '실', detail: '오래오래 건강하게', color: '#e8590c' },
  { id: 'pencil', label: '연필', detail: '배움과 지혜', color: '#1c7ed6' },
  { id: 'microphone', label: '마이크', detail: '무대 위의 스타', color: '#9c36b5' },
  { id: 'ball', label: '공', detail: '활기찬 운동 신경', color: '#f08c00' },
  { id: 'gavel', label: '판사봉', detail: '정의로운 리더', color: '#495057' },
]

export function optionLabel(id) {
  return doljabiOptions.find((option) => option.id === id)?.label ?? id
}
