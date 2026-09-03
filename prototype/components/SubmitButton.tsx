'use client'

import { useFormStatus } from 'react-dom'

export default function SubmitButton({
  children,
  pendingLabel = '正在提交…',
  className,
  disabled = false,
}: {
  children: React.ReactNode
  pendingLabel?: string
  className?: string
  disabled?: boolean
}) {
  const { pending } = useFormStatus()
  return (
    <button
      type="submit"
      className={className}
      disabled={disabled || pending}
      aria-disabled={disabled || pending}
      aria-busy={pending}
    >
      {pending ? pendingLabel : children}
    </button>
  )
}
