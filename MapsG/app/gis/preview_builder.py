from pathlib import Path

from PIL import Image, ImageDraw


def create_preview(destination: Path, title: str, bounds: dict[str, float] | None) -> Path:
    image = Image.new("RGB", (1200, 720), "#edf4ef")
    draw = ImageDraw.Draw(image)
    draw.rectangle((45, 45, 1155, 675), outline="#246b4b", width=6)
    draw.text((80, 90), title, fill="#163c2d", font=None)
    draw.text((80, 130), "GeoCampo - vista previa offline", fill="#246b4b", font=None)
    if bounds:
        text = (
            f"Bounds EPSG:4326: {bounds['min_lng']:.6f}, {bounds['min_lat']:.6f}, "
            f"{bounds['max_lng']:.6f}, {bounds['max_lat']:.6f}"
        )
        draw.text((80, 610), text, fill="#163c2d", font=None)
    image.save(destination, format="PNG", optimize=True)
    return destination

