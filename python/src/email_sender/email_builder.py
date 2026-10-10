from datetime import datetime, timedelta

from src.email_sender.config_loader import ConfigLoader
from src.utils.common.path_utils import PathUtils
from src.utils.complete_logger import get_logger

try:
    from lunardate import LunarDate

    HAVE_LUNAR = True
except Exception(BaseException):
    HAVE_LUNAR = False

logger = get_logger("qq_email")


class EmailBuilder:
    def __init__(self):
        self.email_to_infos = ConfigLoader(conf_dir=PathUtils.from_project_root("src", "config", "email_to")).load()

    def build(self) -> list[dict]:
        email_infos = []
        for email_to in self.email_to_infos:
            # today = date.today()
            today = datetime.strptime("2026-05-11", "%Y-%m-%d")
            today_calendar = today.strftime("%Y年%m月%d日")
            gregorian_calendar = today.strftime("%Y年%m月%d日")
            lunar_calendar = self.get_lunar_str(today.year, today.month, today.day)
            if email_to['birthday']['lunar'] in lunar_calendar or email_to['birthday'][
                'gregorian'] in gregorian_calendar:
                logger.info(f"email_to: {email_to}")
                logger.info(f"gregorian_calendar: {gregorian_calendar}")
                logger.info(f"lunar_calendar: {lunar_calendar}")
                email_infos.append({
                    "to_addrs": email_to['mail']['to_addrs'],
                    "subject": email_to['mail']['subject'],
                    "html_content": self.build_html(email_to['mail']['subject'], today_calendar, gregorian_calendar,
                                                    lunar_calendar)
                })
            else:
                """提前一天提醒"""
                logger.debug(f"提前一天提醒判断：email_to: {email_to}")
                tomorrow = today + timedelta(days=1)
                gregorian_calendar = tomorrow.strftime("%Y年%m月%d日")
                lunar_calendar = self.get_lunar_str(tomorrow.year, tomorrow.month, tomorrow.day)
                if email_to['birthday']['lunar'] in lunar_calendar or email_to['birthday'][
                    'gregorian'] in gregorian_calendar:
                    logger.info(f"email_to: {email_to}")
                    logger.info(f"gregorian_calendar: {gregorian_calendar}")
                    logger.info(f"lunar_calendar: {lunar_calendar}")
                    email_infos.append({
                        "to_addrs": email_to['mail']['to_addrs'],
                        "subject": email_to['mail']['subject'],
                        "html_content": self.build_html(email_to['mail']['subject'], today_calendar, gregorian_calendar,
                                                        lunar_calendar)
                    })
        return email_infos

    def build_html(self, subject, today_calendar, gregorian_calendar, lunar_calendar):
        html = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>""" + subject + """</title>
</head>
<body>
"""
        html += """<h1 style="color: #F12F04;">今天过生日！</h1>""" if today_calendar == gregorian_calendar else """<h1>明天过生日。</h1>"""
        html += """<p>今天是公历 <b>""" + today_calendar + """</b>，生日是：<b>""" + gregorian_calendar + """</b>（""" + lunar_calendar + """）。</p>
</body>
</html>
        """
        return html

    @staticmethod
    def get_lunar_str(year, month, day):
        """
        根据给定的公历日期，返回农历日期的字符串表示。
        如果无法使用 lunardate，则返回 None。
        """
        if not HAVE_LUNAR:
            return None

        try:
            lunar = LunarDate.fromSolarDate(year, month, day)
            month_prefix = f"闰{lunar.month}月，" if lunar.isLeapMonth else ""
            return f"农历 {month_prefix}{lunar.year}年{lunar.month:0>2}月{lunar.day:0>2}日"
        except Exception(BaseException):
            return None
