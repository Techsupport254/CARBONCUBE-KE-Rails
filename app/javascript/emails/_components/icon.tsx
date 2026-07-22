import { Img } from "@react-email/components"

type IconProps = {
  name: string
  size?: number
  color?: string
  alt?: string
}

export function Icon({ name, size = 20, color = "#475569", alt = "" }: IconProps) {
  const baseUrl = "https://api.iconify.design/lucide"
  const url = `${baseUrl}/${name}.svg?color=${encodeURIComponent(color)}&width=${size}&height=${size}`

  return (
    <Img
      src={url}
      width={size}
      height={size}
      alt={alt}
      style={{
        display: "inline-block",
        verticalAlign: "middle",
        border: 0,
        outline: 0,
      }}
    />
  )
}
