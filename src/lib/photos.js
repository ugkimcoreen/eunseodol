const samplePhotos = [
  {
    title: '활짝 웃는 은서',
    image_url: 'https://images.unsplash.com/photo-1546015720-b8b30df5aa27?auto=format&fit=crop&w=1200&q=80',
  },
  {
    title: '호기심 많은 은서',
    image_url: 'https://images.unsplash.com/photo-1515488042361-ee00e0ddd4e4?auto=format&fit=crop&w=1200&q=80',
  },
  {
    title: '봄날의 은서',
    image_url: 'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?auto=format&fit=crop&w=1200&q=80',
  },
  {
    title: '귀여운 순간',
    image_url: 'https://images.unsplash.com/photo-1522771930-78848d9293e8?auto=format&fit=crop&w=1200&q=80',
  },
]

export const fallbackPhotos = Array.from({ length: 16 }, (_, index) => {
  const photo = samplePhotos[index % samplePhotos.length]
  return {
    ...photo,
    id: `sample-${index + 1}`,
    title: `${photo.title} ${index + 1}`,
    win_count: 0,
  }
})
