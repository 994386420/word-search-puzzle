#!/usr/bin/env python3
"""Generate the remaining children's picture-clue assets by category."""

from __future__ import annotations

import argparse
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / "tool" / "generate_image.py"
SOURCE_ROOT = ROOT / "tmp" / "imagegen" / "word-sources"
ASSET_ROOT = ROOT / "assets" / "words"


@dataclass(frozen=True)
class AssetSpec:
    name: str
    subject: str
    exact_symbols: str = ""


SPECS = {
    "animals": [
        AssetSpec("python", "一条完整盘绕的友好绿色蟒蛇，头部抬起，花纹清楚但不吓人"),
        AssetSpec("gorilla", "一只强壮但表情友好的完整大猩猩，稳稳站立"),
        AssetSpec("leopard", "一只完整站立的金黄色花豹，黑色玫瑰斑纹清楚"),
        AssetSpec("jaguar", "一只完整站立的橙黄色美洲豹，体格结实，环形斑纹清楚"),
        AssetSpec("rhino", "一只圆润友好的完整灰色犀牛，鼻角短而安全"),
        AssetSpec("flamingo", "一只完整站立的粉红色火烈鸟，弯曲长颈和长腿清楚"),
        AssetSpec("kangaroo", "一只完整站立的棕黄色袋鼠，育儿袋和粗壮尾巴清楚"),
        AssetSpec("shark", "一条完整游动的友好蓝灰色鲨鱼，鳍和尾巴清楚，不露尖牙"),
        AssetSpec("peacock", "一只完整站立的蓝绿色孔雀，展开圆润华丽的尾屏"),
        AssetSpec("falcon", "一只完整站立的棕灰色猎鹰，翅膀收拢，喙部圆润"),
    ],
    "food": [
        AssetSpec("lasagna", "一块整齐切开的千层面，番茄酱、奶酪和面层清楚可见"),
        AssetSpec("burrito", "一个完整的墨西哥卷饼，切口露出米饭、豆子和蔬菜"),
        AssetSpec("risotto", "一碗奶油蘑菇烩饭，米粒和少量蘑菇片清楚"),
        AssetSpec("tempura", "一小盘金黄色天妇罗虾和两块蔬菜天妇罗"),
        AssetSpec("paella", "一只浅圆锅装着金黄色西班牙海鲜饭，点缀虾和青豆"),
        AssetSpec("tiramisu", "一块方形提拉米苏，奶油夹层和顶部可可粉清楚"),
        AssetSpec("falafel", "三颗金黄色炸鹰嘴豆丸子，其中一颗切开露出绿色香草内馅"),
        AssetSpec("gnocchi", "一小盘圆润的意式团子，配少量番茄酱和罗勒叶"),
        AssetSpec("fondue", "一只温暖的奶酪火锅，旁边只有一根叉子叉着面包块"),
        AssetSpec("sashimi", "一小盘整齐摆放的三文鱼和金枪鱼刺身，切片清楚"),
    ],
    "nature": [
        AssetSpec("river", "一条蜿蜒穿过绿色小山谷的清澈蓝色河流"),
        AssetSpec("ocean", "一朵清晰的蓝绿色海浪，带少量白色浪花"),
        AssetSpec("cloud", "一朵蓬松饱满的白色自然云朵"),
        AssetSpec("forest", "一小簇层次清楚的常绿树和阔叶树组成的森林"),
        AssetSpec("dune", "一座流线清楚的金黄色沙丘，顶部有柔和风纹"),
        AssetSpec("rainbow", "一道完整清楚的七色彩虹，连接两朵小白云"),
        AssetSpec("thunder", "一朵圆润深灰色雷雨云，下面只有一道明亮闪电"),
        AssetSpec("canyon", "一座层理清楚的红橙色峡谷，两侧岩壁之间有深谷"),
        AssetSpec("meadow", "一片绿色草甸，上面点缀少量黄色和粉色小花"),
        AssetSpec("rapids", "一段奔腾的蓝色白水急流，绕过三块圆润岩石"),
        AssetSpec("volcano", "一座圆锥形火山，顶部有少量橙色熔岩和柔和烟雾"),
        AssetSpec("glacier", "一座高大的蓝白色冰川，冰层和裂纹结构清楚"),
        AssetSpec("mountain", "一座雄伟但圆润的高山，山顶覆盖白雪"),
        AssetSpec("savanna", "一小片金色稀树草原，中央是一棵伞形金合欢树"),
        AssetSpec("waterfall", "一道从圆润岩壁落入蓝绿色水潭的瀑布"),
        AssetSpec("tundra", "一小片开阔寒冷苔原，低矮苔藓、圆润岩石和少量远处雪地"),
        AssetSpec("delta", "一条蓝色河流在绿色陆地上分成多条支流汇入海面，鸟瞰视角"),
        AssetSpec("wetland", "一小片浅水湿地，芦苇、水草和两个清楚水洼"),
        AssetSpec("prairie", "一片开阔绿色大草原，长草随风弯曲，点缀少量小花"),
        AssetSpec(
            "plateau",
            "一座完整的红褐色平顶高原地貌，顶部是宽阔平坦的陆地并有少量绿草，"
            "侧面是连续分层岩壁，底部连接一小片远处陆地；明确是大型自然地貌，绝对不要像树桩或木头",
        ),
        AssetSpec("lagoon", "一片被弯曲白沙和绿色植被环绕的清澈蓝绿色潟湖"),
        AssetSpec("geyser", "一道从圆润岩石泉口向上喷出的白色间歇泉水柱"),
        AssetSpec("fjord", "一条狭长深蓝海湾位于两侧高耸圆润雪山之间"),
        AssetSpec("estuary", "一条宽阔河流在绿色河岸之间汇入蓝色海洋的河口"),
        AssetSpec("mangrove", "一小簇生长在浅水中的红树林，拱形支柱根清楚可见"),
    ],
    "sports": [
        AssetSpec("soccer", "一个经典黑白足球，后面有一个简化的小球门"),
        AssetSpec("tennis", "一支青绿色网球拍和一个亮黄色网球"),
        AssetSpec("golf", "一支高尔夫球杆、一个白色高尔夫球和一个小球洞旗"),
        AssetSpec("judo", "一件厚实白色柔道服配黑带，整齐放在红蓝榻榻米上"),
        AssetSpec("skiing", "一对彩色滑雪板、两根雪杖和一副护目镜"),
        AssetSpec("boxing", "一对红色儿童拳击手套，拳套完整并排"),
        AssetSpec("hockey", "一支冰球杆和一个黑色冰球，下面有一小片冰面"),
        AssetSpec("cycling", "一辆完整的儿童运动自行车，侧面三分之二视角"),
        AssetSpec("diving", "一副潜水面镜、呼吸管和一对蓝色脚蹼"),
        AssetSpec("karate", "一件轻便白色空手道服配黑带，旁边是一块断开的木板"),
        AssetSpec("surfing", "一块彩色冲浪板靠在一朵圆润的蓝色海浪前"),
        AssetSpec("rugby", "一个经典棕橙色橄榄形英式橄榄球"),
        AssetSpec("archery", "一把儿童反曲弓、一支箭和一个小型圆靶"),
        AssetSpec("baseball", "一个棒球手套、一个白色棒球和一根木质球棒"),
        AssetSpec("swimming", "一副游泳镜、一顶泳帽和一段蓝色泳道浮标"),
        AssetSpec("fencing", "一副完整击剑面罩、一把安全圆头花剑和一只白色手套"),
        AssetSpec("cricket", "一支木质板球拍、一个红色板球和三根小门柱"),
        AssetSpec("marathon", "一双彩色跑鞋跨过一条终点带，旁边有一个简化秒表"),
        AssetSpec("volleyball", "一个蓝黄白相间的排球，后面有一小段球网"),
        AssetSpec("badminton", "两支轻巧羽毛球拍和一个白色羽毛球"),
        AssetSpec("handball", "一个带清楚拼接纹理的彩色手球，后面有一个简化小球门"),
        AssetSpec("rowing", "一艘完整的单人赛艇和两支船桨，漂在一小片蓝色水面上"),
        AssetSpec("wrestling", "一双红蓝摔跤鞋和一件摔跤服，整齐放在圆形软垫上"),
        AssetSpec("polo", "一顶马术头盔、一根马球杆和一个白色马球"),
        AssetSpec("squash", "一支深色壁球拍和一个小黑色壁球"),
    ],
    "space": [
        AssetSpec("moon", "一颗完整的银灰色月球，表面有清楚但柔和的环形山"),
        AssetSpec("mars", "一颗红橙色火星，表面有深浅地形和小型极冠"),
        AssetSpec("comet", "一颗蓝白色冰质彗核，拖着长而柔和的蓝紫色彗尾"),
        AssetSpec("venus", "一颗金黄色金星，被柔和的旋转云层包围"),
        AssetSpec("planet", "一颗友好的蓝绿类地行星，有海洋、陆地和薄云层"),
        AssetSpec("rocket", "一枚圆润的红白儿童探索火箭，轻柔升空"),
        AssetSpec("saturn", "一颗金黄色土星，拥有宽阔清楚的彩色行星环"),
        AssetSpec("meteor", "一块棕灰色岩石流星，带短而明亮的橙色火焰尾迹"),
        AssetSpec("orbit", "一颗小蓝色行星和一颗小卫星，沿清楚的椭圆轨道运行"),
        AssetSpec("eclipse", "黑色月球遮住金色太阳，周围形成完整明亮的日冕"),
        AssetSpec("aurora", "绿色和紫色极光在一小片圆润雪山上空展开"),
        AssetSpec("jupiter", "一颗木星，奶油色和棕色条纹以及红色大斑清楚"),
        AssetSpec("neptune", "一颗深蓝色海王星，带柔和的浅蓝色云带"),
        AssetSpec("telescope", "一台完整的儿童天文望远镜，安装在三脚架上"),
        AssetSpec("astronaut", "一名友好的儿童宇航员，穿完整白色宇航服站立"),
        AssetSpec("galaxy", "一个清楚完整的蓝紫色旋涡星系，中心明亮，星臂层次分明"),
        AssetSpec("nebula", "一团完整的粉紫与蓝绿色星云，像柔软彩色云朵并带少量星点"),
        AssetSpec("cosmos", "一个圆形小宇宙场景，包含少量不同大小行星、星星和轨道"),
        AssetSpec("pulsar", "一颗小型高密度脉冲星，从两极射出两束对称蓝白光束"),
        AssetSpec("quasar", "一个明亮金白色类星体核心，周围有蓝紫色旋转吸积盘和双向光束"),
        AssetSpec("asteroid", "一块完整不规则的棕灰色小行星，表面布满圆润撞击坑"),
        AssetSpec("uranus", "一颗浅青蓝色天王星，带一圈细而清楚的淡色行星环"),
        AssetSpec("satellite", "一颗完整的友好人造卫星，中央机身和两侧蓝色太阳能板清楚"),
        AssetSpec("gravity", "一颗蓝绿色小行星使周围网格柔和下凹，并吸引两个小球沿轨道靠近"),
        AssetSpec(
            "supernova",
            "一颗没有表面纹理的纯白黄色发光恒星位于正中央，周围形成对称的金色、粉色和紫色"
            "同心气体爆发壳层，带清楚的短放射光束和少量星尘；明确是宇宙恒星爆发，"
            "绝对不要陆地、海洋、行星、地球、颜料飞溅或花朵",
        ),
    ],
    "tech": [
        AssetSpec("pixel", "一朵由大颗彩色方块像素拼成的简单花朵"),
        AssetSpec("binary", "九块圆角玩具方块组成的小网格，每块只显示0或1", "0, 1"),
        AssetSpec("router", "一台圆润白色无线路由器，有两根天线和三道青色信号弧"),
        AssetSpec("browser", "一个圆润的网页浏览器窗口玩具，顶部有三个彩色圆点，中央是地球图形"),
        AssetSpec("server", "一个小型圆角服务器机柜，整齐排列三层设备和状态灯"),
        AssetSpec("network", "五个彩色圆形节点通过发光连线组成清楚的网络"),
        AssetSpec("cache", "一个打开的快速存储盒，小数据方块沿箭头进入并从另一侧出来"),
        AssetSpec("terminal", "一台小型终端屏幕，只显示一个大于号提示符和一个方形光标", ">"),
        AssetSpec("function", "一台输入输出玩具机器，一个圆形积木进入后变成星形积木出来"),
        AssetSpec("variable", "一个圆角玩具盒，正面只显示小写x，盒内可替换彩色形状", "x"),
        AssetSpec("database", "三个堆叠的青蓝色圆柱数据库磁盘，带少量发光状态点"),
        AssetSpec("syntax", "两个彩色圆角大括号积木包围三块代码积木", "{, }"),
        AssetSpec("algorithm", "一条由彩色步骤方块和箭头组成的清楚路径，从金色星星通向小旗"),
        AssetSpec("compiler", "一台友好的编译机器，把彩色代码积木转换成发光齿轮积木"),
        AssetSpec("cloud", "一朵圆润的云计算云，通过发光连线连接一台电脑和一部手机"),
        AssetSpec("kernel", "一颗发光金色核心被保护在圆润青蓝色电脑芯片中央"),
        AssetSpec("pointer", "一只圆润电脑鼠标旁边有一个清楚的大号白色鼠标指针箭头"),
        AssetSpec("protocol", "两台圆润小电脑通过连线交换三块颜色顺序完全一致的数据积木"),
        AssetSpec("firewall", "一道圆润红橙色砖墙保护后方的小电脑，挡住几颗红色数据火花"),
        AssetSpec("backend", "一个彩色应用窗口后方连接着三层圆润服务器和数据库圆柱"),
        AssetSpec("frontend", "一个面向前方的彩色应用窗口，由按钮、图片块和菜单块组成"),
        AssetSpec("deploy", "一枚小型软件火箭从打开的笔记本电脑上平稳升空"),
        AssetSpec("pipeline", "一条透明圆润管道依次连接四台小机器，彩色数据方块从左向右流动"),
        AssetSpec("cluster", "四台小型圆润服务器围成一组，通过青色连线连接中央节点"),
        AssetSpec("runtime", "一个发光齿轮正在圆形计时环中运转，旁边有播放三角按钮"),
    ],
}


BACKGROUNDS = {
    "animals": "浅薄荷绿色纯背景 #E4F2DD",
    "food": "浅蜜桃橙色纯背景 #FFD8C1",
    "nature": "浅薄荷绿色纯背景 #E5F4D7",
    "sports": "浅天空蓝色纯背景 #DDF1F5",
    "space": "浅薰衣草紫色纯背景 #E8E0F7",
    "tech": "浅青绿色纯背景 #DDF5F0",
}


def build_prompt(category: str, spec: AssetSpec) -> str:
    symbol_rule = (
        f"画面只允许出现这些精确符号：{spec.exact_symbols}；不要出现其他文字或符号。"
        if spec.exact_symbols
        else "不要出现任何文字、字母、数字或符号。"
    )
    return (
        "儿童英语找词游戏的方形图片线索插画，与项目App图标完全一致的视觉语言。"
        f"主体：{spec.subject}。"
        "使用高级柔和3D黏土玩具质感，饱满圆润造型，轻微手工纹理，清晰关键特征，"
        "青绿色、珊瑚粉、阳光黄、叶绿和深梅紫作为点缀。"
        "画面只表达一个词义，主体居中且占画面约70%，完整不裁切，四周充分留白，"
        f"{BACKGROUNDS[category]}，柔和明亮棚拍光，轻微落地阴影。"
        f"{symbol_rule}"
        "不要人物（宇航员除外），不要多余道具，不要复杂场景，不要边框，不要Logo，"
        "不要水印，不要emoji，不要贴纸表，不要照片写实，不要锐利危险造型。"
    )


def generate(category: str, *, force: bool, only: str | None = None) -> int:
    output_dir = ASSET_ROOT / category
    source_dir = SOURCE_ROOT / category
    output_dir.mkdir(parents=True, exist_ok=True)
    source_dir.mkdir(parents=True, exist_ok=True)
    failures = 0

    for index, spec in enumerate(SPECS[category], start=1):
        if only is not None and spec.name != only:
            continue
        output = output_dir / f"{spec.name}.webp"
        if output.exists() and not force:
            print(f"SKIP {category}/{spec.name}", flush=True)
            continue

        command = [
            sys.executable,
            str(GENERATOR),
            build_prompt(category, spec),
            "--size",
            "1024x1024",
            "--quality",
            "medium",
            "--output-dir",
            str(source_dir),
            "--name",
            f"{spec.name}-source",
        ]
        print(
            f"GENERATE {category}/{spec.name} ({index}/{len(SPECS[category])})",
            flush=True,
        )
        result = subprocess.run(command, cwd=ROOT, check=False)
        if result.returncode != 0:
            failures += 1
            print(f"FAILED {category}/{spec.name}", file=sys.stderr, flush=True)
            continue

        candidates = sorted(source_dir.glob(f"{spec.name}-source.*"))
        if not candidates:
            failures += 1
            print(f"FAILED {category}/{spec.name}: source missing", file=sys.stderr)
            continue
        source = candidates[-1]
        with Image.open(source) as image:
            final = ImageOps.fit(
                image.convert("RGB"),
                (512, 512),
                method=Image.Resampling.LANCZOS,
            )
            final.save(output, "WEBP", quality=88, method=6)
        print(f"DONE {category}/{spec.name}", flush=True)

    return failures


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("category", choices=tuple(SPECS))
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--only", help="Generate one named asset from the category")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.only is not None and not any(
        spec.name == args.only for spec in SPECS[args.category]
    ):
        print(
            f"Unknown asset for {args.category}: {args.only}",
            file=sys.stderr,
        )
        return 2
    return 1 if generate(args.category, force=args.force, only=args.only) else 0


if __name__ == "__main__":
    raise SystemExit(main())
