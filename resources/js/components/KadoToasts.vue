<script setup>
const toastStore = useToastStore()
const router = useRouter()

const open = (toast) => {
  toastStore.dismiss(toast.id)
  if (toast.to) {
    router.push(toast.to)
  }
}
</script>

<template>
  <div class="pointer-events-none fixed inset-x-4 top-4 z-50 sm:left-auto sm:right-6 sm:w-80 md:top-[150px]" aria-live="polite">
    <TransitionGroup tag="div"
                     class="flex flex-col gap-2"
                     enter-active-class="transition duration-300 ease-out"
                     enter-from-class="translate-x-full opacity-0"
                     leave-active-class="transition duration-200 ease-in"
                     leave-to-class="translate-x-full opacity-0">
      <div v-for="toast in toastStore.toasts"
           :key="toast.id"
           class="pointer-events-auto flex cursor-pointer items-start gap-2 border-2 border-solid border-kado-teal-500 bg-kado-blue-100 p-2 text-sm shadow-lg"
           role="status"
           @click="open(toast)">
        <img v-if="toast.icon"
             :src="toast.icon"
             alt=""
             class="mt-0.5 shrink-0" />
        <div class="min-w-0 flex-1">
          <p v-if="toast.title" class="m-0 font-bold text-kado-teal-500">{{ toast.title }}</p>
          <p class="m-0 break-words">{{ toast.text }}</p>
        </div>
        <button type="button"
                class="shrink-0 cursor-pointer border-0 bg-transparent px-1 font-bold text-kado-teal-500"
                aria-label="Fermer"
                @click.stop="toastStore.dismiss(toast.id)">
          ×
        </button>
      </div>
    </TransitionGroup>
  </div>
</template>
