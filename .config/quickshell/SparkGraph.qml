import QtQuick

// A small usage graph for the system panel (owner, 2026-10-18): `values` (percent, oldest first)
// drawn right-aligned over `length` slots, as a line with a flat fill under it. Square, no
// smoothing, like the rest of the shell.
Canvas {
    id: graph
    property var values: []
    property int length: 30

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = Theme.bg
        ctx.fillRect(0, 0, width, height)
        if (values.length < 2)
            return
        const step = width / (length - 1)
        const x0 = width - (values.length - 1) * step
        const y = v => height - 2 - Math.max(0, Math.min(100, v)) / 100 * (height - 4)
        ctx.beginPath()
        ctx.moveTo(x0, height)
        for (let i = 0; i < values.length; i++)
            ctx.lineTo(x0 + i * step, y(values[i]))
        ctx.lineTo(width, height)
        ctx.closePath()
        ctx.fillStyle = Theme.surfaceSelected
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < values.length; i++) {
            if (i === 0) ctx.moveTo(x0, y(values[0]))
            else ctx.lineTo(x0 + i * step, y(values[i]))
        }
        ctx.strokeStyle = Theme.fg
        ctx.lineWidth = 2
        ctx.stroke()
    }
}
