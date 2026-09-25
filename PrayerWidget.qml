import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "prayerTimes"

    // Prayer times data
    property string fajr: ""
    property string dhuhr: ""
    property string asr: ""
    property string maghrib: ""
    property string isha: ""
    property string imsak: ""
    property string sunrise: ""
    property string dateHijr: ""
    property string dateGreg: ""

    // Fasting texts
    property string todayFastingReason: ""
    property string tomorrowFastingReason: ""
    property string barFastingText: ""

    // Current prayer period
    property string currName: ""
    property string nextName: ""
    property string nextTime: ""
    property int nextTimeSec: 0
    property int nextTotalSeconds: 0

    // Settings properties
    property string language: pluginData.language || "en"
    readonly property bool isAr: root.language === "ar"

    property int refreshInterval: (Number(pluginData.refreshInterval) || 5) * 60000
    property string lat: pluginData.lat || "-6.2088"
    property string lon: pluginData.lon || "106.8456"
    property string method: pluginData.method || ""
    property string school: pluginData.school || "0"
    property int notifyThresholdSec: (Number(pluginData.notifyMinutes) || 15) * 60
    property bool notificationsEnabled: pluginData.notificationsEnabled ?? true
    property string notificationUrgency: ["low", "normal", "critical"].indexOf(pluginData.notificationUrgency) !== -1 ? pluginData.notificationUrgency : "critical"
    property bool iconOnly: pluginData.iconOnly ?? false
    property bool showSeconds: pluginData.showSeconds ?? false
    property bool use12H: pluginData.use12H ?? false

    // Fasting Reminders Settings
    property bool fastingReminderEveEnabled: pluginData.fastingReminderEveEnabled ?? true
    property int fastingReminderEveHour: parseInt(pluginData.fastingReminderEveHour, 10) || 21
    property bool fastingReminderMorningEnabled: pluginData.fastingReminderMorningEnabled ?? true
    property int fastingReminderMorningHour: parseInt(pluginData.fastingReminderMorningHour, 10) || 4

    // Offsets
    property string tuneImsak: (pluginData.tuneImsak !== "0") ? pluginData.tuneImsak : (pluginData.tuneFajr || "0")
    property string tuneFajr: pluginData.tuneFajr || "0"
    property string tuneSunrise: pluginData.tuneSunrise || "0"
    property string tuneDhuhr: pluginData.tuneDhuhr || "0"
    property string tuneAsr: pluginData.tuneAsr || "0"
    property string tuneMaghrib: pluginData.tuneMaghrib || "0"
    property string tuneIsha: pluginData.tuneIsha || "0"

    // Internal state
    property bool fetching: false
    property int retryCount: 0
    property bool _wasUrgent: false
    property bool _wasAtTime: false

    readonly property bool isUrgent: nextTotalSeconds > 0 && nextTotalSeconds <= notifyThresholdSec
    readonly property color accentColor: Theme.primary
    readonly property color accentBg: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.18)
    readonly property color subtleBg: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.05)

    // Notification processes
    Process { id: prayerNotifyProc; running: false }
    Process { id: errorNotifyProc; running: false }
    Process { id: fastingNotifyProc; running: false }

    onPluginServiceChanged: {
        if (pluginService) fetchOrProcess();
    }

    onLatChanged: debounceTimer.restart()
    onLonChanged: debounceTimer.restart()
    onMethodChanged: debounceTimer.restart()
    onSchoolChanged: debounceTimer.restart()
    onLanguageChanged: {
        var currentData = getTodayDataFromState();
        if (currentData) processPrayerData(currentData);
    }

    onTuneImsakChanged: debounceTimer.restart()
    onTuneFajrChanged: debounceTimer.restart()
    onTuneSunriseChanged: debounceTimer.restart()
    onTuneDhuhrChanged: debounceTimer.restart()
    onTuneAsrChanged: debounceTimer.restart()
    onTuneMaghribChanged: debounceTimer.restart()
    onTuneIshaChanged: debounceTimer.restart()

    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: fetchOrProcess()
    }

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        running: pluginService !== null
        repeat: true
        triggeredOnStart: false
        onTriggered: fetchOrProcess()
    }

    SystemClock {
        id: clock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
        onDateChanged: {
            if (root.nextTimeSec > 0)
                updateCountdown();
            checkAndTriggerFastingReminders();
        }
    }

    Timer {
        id: retryTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root.fetching = false;
            fetchPrayerTimes();
        }
    }

    readonly property string iconPath: {
        let fullUrl = Qt.resolvedUrl("icon.svg").toString();
        return fullUrl.replace("file://", "");
    }

    function getPrayerName(standardKey) {
        if (!root.isAr) return standardKey;
        var names = {
            "Imsak": "الإمساك", "Fajr": "الفجر", "Sunrise": "الشروق",
            "Dhuhr": "الظهر", "Asr": "العصر", "Maghrib": "المغرب", "Isha": "العشاء"
        };
        return names[standardKey] || standardKey;
    }

    function sendPrayerNotification() {
        if (!root.notificationsEnabled) return;
        var mins = Math.ceil(root.nextTotalSeconds / 60);
        var title = root.isAr ? "اقتراب موعد الصلاة" : "Prayer Reminder";
        var body = root.isAr ?
            (getPrayerName(root.nextName) + " خلال " + mins + " دقيقة (الساعة " + root.formatTime(root.nextTime) + ")") :
            (root.nextName + " in " + mins + " min (at " + root.formatTime(root.nextTime) + ")");

        prayerNotifyProc.command = ["notify-send", "-a", "Prayer Widget", "-u", root.notificationUrgency, "-i", iconPath, title, body];
        prayerNotifyProc.running = true;
    }

    function sendPrayerTimeNotification() {
        if (!root.notificationsEnabled) return;
        var title = root.isAr ? "حان وقت الصلاة" : "Prayer Time";
        var body = root.isAr ? ("حان الآن موعد أذان " + getPrayerName(root.nextName)) : ("Time for " + root.nextName);

        prayerNotifyProc.command = ["notify-send", "-a", "Prayer Widget", "-u", root.notificationUrgency, "-i", iconPath, title, body];
        prayerNotifyProc.running = true;
    }

    function sendFastingNotification(title, message) {
        if (!root.notificationsEnabled) return;
        fastingNotifyProc.command = ["notify-send", "-a", "Prayer Widget", "-u", "normal", "-i", iconPath, title, message];
        fastingNotifyProc.running = true;
    }

    function sendErrorNotification(message) {
        if (!root.notificationsEnabled) return;
        errorNotifyProc.command = ["notify-send", "-a", "Prayer Widget", "-u", root.notificationUrgency, "-i", iconPath, "Prayer Widget Error", message];
        errorNotifyProc.running = true;
    }

    function checkFastingDay(dayEntry) {
        if (!dayEntry || !dayEntry.date || !dayEntry.date.hijri)
            return null;

        var hijri = dayEntry.date.hijri;
        var hDay = parseInt(hijri.day, 10);
        var hMonth = hijri.month ? parseInt(hijri.month.number, 10) : 0;
        var greg = dayEntry.date.gregorian;
        var dayName = (greg && greg.weekday) ? greg.weekday.en : "";

        var reasonsAr = [];
        var reasonsEn = [];

        // 1. Weekly: Monday & Thursday
        if (dayName === "Monday") {
            reasonsAr.push("الإثنين");
            reasonsEn.push("Monday");
        } else if (dayName === "Thursday") {
            reasonsAr.push("الخميس");
            reasonsEn.push("Thursday");
        }

        // 2. White Days (13, 14, 15) - Excluding 13 Dhu al-Hijjah
        if (hDay === 13 || hDay === 14 || hDay === 15) {
            if (!(hMonth === 12 && hDay === 13)) {
                reasonsAr.push("الأيام البيض (" + hDay + ")");
                reasonsEn.push("White Day (" + hDay + ")");
            }
        }

        // 3. Annual Days
        if (hMonth === 12 && hDay === 9) {
            reasonsAr.push("يوم عرفة");
            reasonsEn.push("Day of Arafah");
        }
        if (hMonth === 1 && hDay === 9) {
            reasonsAr.push("تاسوعاء");
            reasonsEn.push("Tasu'ah");
        }
        if (hMonth === 1 && hDay === 10) {
            reasonsAr.push("عاشوراء");
            reasonsEn.push("Ashura");
        }

        if (reasonsAr.length === 0)
            return null;

        return {
            textAr: reasonsAr.join(" و "),
            textEn: reasonsEn.join(" & ")
        };
    }

    function checkAndTriggerFastingReminders() {
        if (!root.notificationsEnabled) return;

        var calendarData = pluginService.loadPluginState("prayerTimes", "calendarData", []);
        if (!calendarData || calendarData.length === 0) return;

        var now = clock.date;
        var currentHour = now.getHours();

        // 1. Night Before Reminder
        if (root.fastingReminderEveEnabled && currentHour === root.fastingReminderEveHour) {
            var tomorrow = new Date(now);
            tomorrow.setDate(tomorrow.getDate() + 1);
            var tomorrowStr = Qt.formatDate(tomorrow, "dd-MM-yyyy");

            var tomorrowData = null;
            for (var i = 0; i < calendarData.length; i++) {
                if (calendarData[i].date && calendarData[i].date.gregorian && calendarData[i].date.gregorian.date === tomorrowStr) {
                    tomorrowData = calendarData[i];
                    break;
                }
            }

            if (tomorrowData) {
                var fastingEve = checkFastingDay(tomorrowData);
                if (fastingEve) {
                    var eveKey = tomorrowStr + "|eve|" + fastingEve.textEn;
                    var lastEveKey = pluginService.loadPluginState("prayerTimes", "lastFastingEveKey", "");
                    if (lastEveKey !== eveKey) {
                        pluginService.savePluginState("prayerTimes", "lastFastingEveKey", eveKey);
                        var titleEve = root.isAr ? "تذكير: صيام سُنّة غداً" : "Sunnah Fasting Tomorrow";
                        var bodyEve = root.isAr ? ("غداً إن شاء الله صيام: " + fastingEve.textAr + ". جهّز نيتك وسحورك.") : ("Tomorrow: " + fastingEve.textEn + ". Don't forget your intention and Suhur.");
                        sendFastingNotification(titleEve, bodyEve);
                    }
                }
            }
        }

        // 2. Fasting Day Morning Reminder
        if (root.fastingReminderMorningEnabled && currentHour === root.fastingReminderMorningHour) {
            var todayStr = Qt.formatDate(now, "dd-MM-yyyy");
            var todayData = null;
            for (var j = 0; j < calendarData.length; j++) {
                if (calendarData[j].date && calendarData[j].date.gregorian && calendarData[j].date.gregorian.date === todayStr) {
                    todayData = calendarData[j];
                    break;
                }
            }

            if (todayData) {
                var fastingToday = checkFastingDay(todayData);
                if (fastingToday) {
                    var todayKey = todayStr + "|morning|" + fastingToday.textEn;
                    var lastMorningKey = pluginService.loadPluginState("prayerTimes", "lastFastingMorningKey", "");
                    if (lastMorningKey !== todayKey) {
                        pluginService.savePluginState("prayerTimes", "lastFastingMorningKey", todayKey);
                        var titleMorning = root.isAr ? "اليوم يوم صيام مبارك" : "Fasting Day Reminder";
                        var bodyMorning = root.isAr ? ("اليوم صيام: " + fastingToday.textAr + ". تقبل الله طاعتكم.") : ("Today is: " + fastingToday.textEn + ". May Allah accept your fast.");
                        sendFastingNotification(titleMorning, bodyMorning);
                    }
                }
            }
        }
    }

    function updateCountdown() {
        var now = clock.date;
        var nowSec = now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds();

        var rawDiff = root.nextTimeSec - nowSec;
        var diff = rawDiff;
        if (diff < 0) diff += 86400;

        root.nextTotalSeconds = diff;

        var dhuhrSec = timeToMinutes(root.dhuhr) * 60;
        var maghribSec = timeToMinutes(root.maghrib) * 60;

        if (nowSec < dhuhrSec) {
            if (root.todayFastingReason !== "") {
                root.barFastingText = (root.isAr ? "صيام اليوم: " : "Today Fast: ") + root.todayFastingReason;
            } else {
                root.barFastingText = "";
            }
        } else if (nowSec >= maghribSec) {
            if (root.tomorrowFastingReason !== "") {
                root.barFastingText = (root.isAr ? "صيام الغد: " : "Tomorrow Fast: ") + root.tomorrowFastingReason;
            } else {
                root.barFastingText = "";
            }
        } else {
            root.barFastingText = "";
        }

        var urgent = diff > 0 && diff <= root.notifyThresholdSec;
        var todayKey = Qt.formatDate(clock.date, "yyyy-MM-dd");
        var baseKey = todayKey + "|" + root.nextName + "|" + root.nextTime;

        if (root.notificationsEnabled && urgent && !root._wasUrgent) {
            var lastNotified = pluginService.loadPluginState("prayerTimes", "lastNotifiedThresholdKey", "");
            if (lastNotified !== baseKey) {
                pluginService.savePluginState("prayerTimes", "lastNotifiedThresholdKey", baseKey);
                sendPrayerNotification();
            }
        }

        var atTime = (rawDiff <= 0 && rawDiff > -60);
        if (root.notificationsEnabled && atTime && !root._wasAtTime) {
            var lastAtTime = pluginService.loadPluginState("prayerTimes", "lastNotifiedAtKey", "");
            if (lastAtTime !== baseKey) {
                pluginService.savePluginState("prayerTimes", "lastNotifiedAtKey", baseKey);
                sendPrayerTimeNotification();
            }
        }

        root._wasUrgent = root.notificationsEnabled && urgent;
        root._wasAtTime = root.notificationsEnabled && atTime;
    }

    function buildTuneString() {
        return root.tuneImsak + "," + root.tuneFajr + "," + root.tuneSunrise + "," + root.tuneDhuhr + "," + root.tuneAsr + "," + root.tuneMaghrib + "," + "0" + "," + root.tuneIsha + "," + "0";
    }

    function stripTimezone(timeStr) {
        return timeStr ? timeStr.split(" ")[0] : "";
    }

    function timeToMinutes(hhmm) {
        if (!hhmm) return 0;
        var parts = hhmm.split(":");
        return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
    }

    function formatTime(time24h) {
        if (!time24h) return "";
        if (!root.use12H) return time24h;

        var parts = time24h.split(":");
        if (parts.length < 2) return time24h;

        var hours = parseInt(parts[0], 10);
        var minutes = parts[1];
        var ampm = root.isAr ? (hours >= 12 ? "م" : "ص") : (hours >= 12 ? "PM" : "AM");

        hours = hours % 12;
        if (hours === 0) hours = 12;
        var hoursStr = hours < 10 ? "0" + hours : hours.toString();
        return hoursStr + ":" + minutes + " " + ampm;
    }

    function formatCountdown(totalSeconds) {
        if (totalSeconds <= 0)
            return root.showSeconds ? "00:00" : (root.isAr ? "0 دقيقة" : "0 min");
        var h = Math.floor(totalSeconds / 3600);
        var m = Math.floor((totalSeconds % 3600) / 60);
        var s = totalSeconds % 60;
        var mm = (m < 10 ? "0" : "") + m;
        var ss = (s < 10 ? "0" : "") + s;
        var hh = (h < 10 ? "0" : "") + h;

        if (root.showSeconds) {
            if (h > 0) return hh + ":" + mm + ":" + ss;
            return mm + ":" + ss;
        } else {
            if (h > 0) return hh + ":" + mm;
            return m + (root.isAr ? " دقيقة" : " min");
        }
    }

    function determinePrayerPeriod(nowStr, fajrT, dhuhrT, asrT, maghribT, ishaT) {
        if (nowStr < fajrT) return { currName: "Isha", currTime: ishaT, nextName: "Fajr", nextTime: fajrT };
        if (nowStr < dhuhrT) return { currName: "Fajr", currTime: fajrT, nextName: "Dhuhr", nextTime: dhuhrT };
        if (nowStr < asrT) return { currName: "Dhuhr", currTime: dhuhrT, nextName: "Asr", nextTime: asrT };
        if (nowStr < maghribT) return { currName: "Asr", currTime: asrT, nextName: "Maghrib", nextTime: maghribT };
        if (nowStr < ishaT) return { currName: "Maghrib", currTime: maghribT, nextName: "Isha", nextTime: ishaT };
        return { currName: "Isha", currTime: ishaT, nextName: "Fajr", nextTime: fajrT };
    }

    function cacheMatchesSettings() {
        var fetchedLat = pluginService.loadPluginState("prayerTimes", "fetchedLat", "");
        var fetchedLon = pluginService.loadPluginState("prayerTimes", "fetchedLon", "");
        var fetchedMethod = pluginService.loadPluginState("prayerTimes", "fetchedMethod", "");
        var fetchedSchool = pluginService.loadPluginState("prayerTimes", "fetchedSchool", "0");
        var fetchedTune = pluginService.loadPluginState("prayerTimes", "fetchedTune", "0,0,0,0,0,0,0,0,0");
        return fetchedLat === root.lat && fetchedLon === root.lon && fetchedMethod === root.method && fetchedSchool === root.school && fetchedTune === buildTuneString();
    }

    function getTodayDataFromState() {
        if (!cacheMatchesSettings()) return null;
        var calendarData = pluginService.loadPluginState("prayerTimes", "calendarData", []);
        if (!calendarData || calendarData.length === 0) return null;
        var today = Qt.formatDate(new Date(), "dd-MM-yyyy");
        for (var i = 0; i < calendarData.length; i++) {
            var entry = calendarData[i];
            if (entry.date && entry.date.gregorian && entry.date.gregorian.date === today)
                return entry;
        }
        return null;
    }

    function tryFallbackFromState() {
        if (!cacheMatchesSettings()) return;
        var calendarData = pluginService.loadPluginState("prayerTimes", "calendarData", []);
        if (!calendarData || calendarData.length === 0) return;
        var today = Qt.formatDate(new Date(), "dd-MM-yyyy");
        for (var i = 0; i < calendarData.length; i++) {
            var entry = calendarData[i];
            if (entry.date && entry.date.gregorian && entry.date.gregorian.date === today) {
                processPrayerData(entry);
                return;
            }
        }
        processPrayerData(calendarData[0]);
    }

    function fetchOrProcess() {
        if (!pluginService) return;
        var todayData = getTodayDataFromState();
        if (todayData) processPrayerData(todayData);
        else fetchPrayerTimes();
    }

    function forceRefresh() {
        if (root.fetching) return;
        pluginService.savePluginState("prayerTimes", "calendarData", []);
        pluginService.savePluginState("prayerTimes", "fetchedMethod", "__force__");
        fetchPrayerTimes();
    }

    function fetchPrayerTimes() {
        if (root.fetching) return;
        root.fetching = true;

        var requestLat = root.lat;
        var requestLon = root.lon;
        var requestMethod = root.method;
        var requestSchool = root.school;
        var tuneString = buildTuneString();

        var fromDate = new Date();
        var toDate = new Date(fromDate);
        toDate.setDate(toDate.getDate() + 6);

        var fromStr = Qt.formatDate(fromDate, "dd-MM-yyyy");
        var toStr = Qt.formatDate(toDate, "dd-MM-yyyy");

        var url = "https://api.aladhan.com/v1/calendar/from/" + fromStr + "/to/" + toStr + "?latitude=" + requestLat + "&longitude=" + requestLon + "&school=" + requestSchool;
        if (requestMethod !== "") url += "&method=" + requestMethod;
        if (tuneString !== "0,0,0,0,0,0,0,0,0") url += "&tune=" + tuneString;

        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.fetching = false;

            if (requestLat !== root.lat || requestLon !== root.lon || requestMethod !== root.method || requestSchool !== root.school || tuneString !== buildTuneString()) {
                root.retryCount = 0;
                fetchOrProcess();
                return;
            }

            if (xhr.status === 200) {
                root.retryCount = 0;
                try {
                    var json = JSON.parse(xhr.responseText);
                    if (json.code === 200 && json.data && json.data.length > 0) {
                        pluginService.savePluginState("prayerTimes", "calendarData", json.data);
                        pluginService.savePluginState("prayerTimes", "fetchedLat", requestLat);
                        pluginService.savePluginState("prayerTimes", "fetchedLon", requestLon);
                        pluginService.savePluginState("prayerTimes", "fetchedMethod", requestMethod);
                        pluginService.savePluginState("prayerTimes", "fetchedSchool", requestSchool);
                        pluginService.savePluginState("prayerTimes", "fetchedTune", tuneString);

                        var todayStr = Qt.formatDate(new Date(), "dd-MM-yyyy");
                        var todayData = null;
                        for (var i = 0; i < json.data.length; i++) {
                            if (json.data[i].date && json.data[i].date.gregorian && json.data[i].date.gregorian.date === todayStr) {
                                todayData = json.data[i];
                                break;
                            }
                        }
                        processPrayerData(todayData || json.data[0]);
                    } else {
                        var fb = getTodayDataFromState();
                        if (fb) processPrayerData(fb);
                        else sendErrorNotification("API error: " + (json.status || "Unknown"));
                    }
                } catch (e) {
                    var cached = getTodayDataFromState();
                    if (cached) processPrayerData(cached);
                    else sendErrorNotification("JSON parse error: " + e.message);
                }
            } else if (xhr.status === 429) {
                root.retryCount++;
                var backoff = Math.min(30000 * Math.pow(2, root.retryCount - 1), 600000);
                var rateFb = getTodayDataFromState();
                if (rateFb) processPrayerData(rateFb);
                retryTimer.interval = backoff;
                root.fetching = true;
                retryTimer.restart();
            } else {
                tryFallbackFromState();
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function processPrayerData(data) {
        var timings = data.timings;
        var dateInfo = data.date;

        var fajrTime = stripTimezone(timings.Fajr);
        var dhuhrTime = stripTimezone(timings.Dhuhr);
        var asrTime = stripTimezone(timings.Asr);
        var maghribTime = stripTimezone(timings.Maghrib);
        var ishaTime = stripTimezone(timings.Isha);

        root.fajr = fajrTime;
        root.dhuhr = dhuhrTime;
        root.asr = asrTime;
        root.maghrib = maghribTime;
        root.isha = ishaTime;
        root.imsak = stripTimezone(timings.Imsak || "");
        root.sunrise = stripTimezone(timings.Sunrise || "");

        root.dateGreg = dateInfo.readable || "";
        if (dateInfo.hijri) {
            var mName = root.isAr ? (dateInfo.hijri.month.ar || dateInfo.hijri.month.en) : dateInfo.hijri.month.en;
            root.dateHijr = dateInfo.hijri.day + " " + mName + " " + dateInfo.hijri.year;
        }

        // 1. فحص صيام اليوم
        var fastCheckToday = checkFastingDay(data);
        root.todayFastingReason = fastCheckToday ? (root.isAr ? fastCheckToday.textAr : fastCheckToday.textEn) : "";

        // 2. فحص صيام الغد من الـ Calendar Data المخزنة
        var calendarData = pluginService.loadPluginState("prayerTimes", "calendarData", []);
        var tomorrow = new Date(clock.date);
        tomorrow.setDate(tomorrow.getDate() + 1);
        var tomorrowStr = Qt.formatDate(tomorrow, "dd-MM-yyyy");

        var tomorrowData = null;
        for (var i = 0; i < calendarData.length; i++) {
            if (calendarData[i].date && calendarData[i].date.gregorian && calendarData[i].date.gregorian.date === tomorrowStr) {
                tomorrowData = calendarData[i];
                break;
            }
        }
        if (tomorrowData) {
            var fastCheckTomorrow = checkFastingDay(tomorrowData);
            root.tomorrowFastingReason = fastCheckTomorrow ? (root.isAr ? fastCheckTomorrow.textAr : fastCheckTomorrow.textEn) : "";
        } else {
            root.tomorrowFastingReason = "";
        }

        var nowStr = Qt.formatTime(clock.date, "HH:mm");
        var period = determinePrayerPeriod(nowStr, fajrTime, dhuhrTime, asrTime, maghribTime, ishaTime);

        root.nextTimeSec = timeToMinutes(period.nextTime) * 60;

        if (root.nextName !== period.nextName) {
            root._wasUrgent = false;
            root._wasAtTime = false;
        }

        root.currName = period.currName;
        root.nextName = period.nextName;
        root.nextTime = period.nextTime;

        updateCountdown();
        checkAndTriggerFastingReminders();
    }

    property var prayerIcons: ({
        "Fajr": "bedtime", "Dhuhr": "wb_sunny", "Asr": "light_mode",
        "Maghrib": "wb_twilight", "Isha": "bedtime"
    })

    function getPrayerIcon(name) {
        return root.prayerIcons[name] || "mosque";
    }

    // Horizontal bar pill
    horizontalBarPill: Component {
        Row {
            spacing: root.iconOnly ? 0 : Theme.spacingXS
            rightPadding: root.iconOnly ? 0 : Theme.spacingS

            DankIcon {
                name: root.getPrayerIcon(root.currName)
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !root.iconOnly
                text: root.nextTime !== "" ? (root.getPrayerName(root.nextName) + " " + root.formatTime(root.nextTime)) : (root.isAr ? "جار التحميل…" : "Loading…")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconOnly ? 0 : implicitWidth
            }

            StyledText {
                visible: !root.iconOnly && root.nextTime !== ""
                text: "·"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                leftPadding: 2
                rightPadding: 2
                anchors.verticalCenter: parent.verticalCenter
                width: (!root.iconOnly && root.nextTime !== "") ? implicitWidth : 0
            }

            StyledText {
                visible: !root.iconOnly && root.nextTime !== ""
                text: root.formatCountdown(root.nextTotalSeconds)
                font.pixelSize: Theme.fontSizeSmall
                font.weight: root.isUrgent ? Font.Bold : Font.Normal
                color: root.isUrgent ? root.accentColor : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                width: (!root.iconOnly && root.nextTime !== "") ? implicitWidth : 0
            }

            // علامة الصيام في الـ Topbar (تختفي من الظهر حتى المغرب)
            Row {
                visible: !root.iconOnly && root.barFastingText !== ""
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "·"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    leftPadding: 2
                    rightPadding: 2
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankIcon {
                    name: "wb_twilight"
                    size: Theme.iconSize - 8
                    color: root.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.barFastingText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: root.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // Vertical bar pill
    verticalBarPill: Component {
        Column {
            spacing: 2

            DankIcon {
                name: root.getPrayerIcon(root.currName)
                size: Theme.iconSize - 6
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.nextTime !== ""
                text: root.formatCountdown(root.nextTotalSeconds)
                font.pixelSize: Theme.fontSizeSmall - 2
                color: root.isUrgent ? root.accentColor : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            DankIcon {
                visible: root.barFastingText !== ""
                name: "wb_twilight"
                size: Theme.iconSize - 8
                color: root.accentColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Popout panel
    popoutContent: Component {
        Item {
            id: popoutRoot
            width: 270
            implicitWidth: 270
            implicitHeight: content.implicitHeight + Theme.spacingM * 2

            Column {
                id: content
                spacing: Theme.spacingS
                anchors.fill: parent
                anchors.margins: Theme.spacingM

                // Header with dates & refresh button
                Item {
                    width: parent.width
                    height: Math.max(dateCol.implicitHeight, refreshPill.height)

                    Column {
                        id: dateCol
                        spacing: 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: root.dateHijr
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: root.dateGreg
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }
                    }

                    Rectangle {
                        id: refreshPill
                        width: 28
                        height: 28
                        radius: width / 2
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: refreshArea.containsMouse ? Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.12) : root.subtleBg

                        DankIcon {
                            name: "refresh"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.forceRefresh()
                        }
                    }
                }

                // 1. كارت صيام اليوم (يظل موجوداً في النافذة الكبيرة طوال اليوم)
                Rectangle {
                    visible: root.todayFastingReason !== ""
                    width: parent.width
                    height: visible ? (todayRow.implicitHeight + Theme.spacingS * 2) : 0
                    radius: 8
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                    border.color: Theme.primary
                    border.width: 1

                    Row {
                        id: todayRow
                        spacing: Theme.spacingS
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2

                        DankIcon {
                            name: "wb_twilight"
                            size: Theme.iconSize - 2
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: (root.isAr ? "صيام اليوم: " : "Today's Fast: ") + root.todayFastingReason
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            width: parent.width - (Theme.iconSize + Theme.spacingS)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // 2. كارت صيام الغد (يظل موجوداً في النافذة الكبيرة أيضاً)
                Rectangle {
                    visible: root.tomorrowFastingReason !== ""
                    width: parent.width
                    height: visible ? (tomorrowRow.implicitHeight + Theme.spacingS * 2) : 0
                    radius: 8
                    color: Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.06)
                    border.color: Theme.surfaceVariantText
                    border.width: 1

                    Row {
                        id: tomorrowRow
                        spacing: Theme.spacingS
                        anchors.centerIn: parent
                        width: parent.width - Theme.spacingM * 2

                        DankIcon {
                            name: "bedtime"
                            size: Theme.iconSize - 2
                            color: Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: (root.isAr ? "صيام الغد: " : "Tomorrow's Fast: ") + root.tomorrowFastingReason
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceText
                            wrapMode: Text.WordWrap
                            width: parent.width - (Theme.iconSize + Theme.spacingS)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Countdown card
                Rectangle {
                    width: parent.width
                    height: cdCol.implicitHeight + Theme.spacingM * 2
                    radius: 8
                    color: root.accentBg
                    border.color: root.accentColor
                    border.width: 1

                    Column {
                        id: cdCol
                        anchors.centerIn: parent
                        spacing: 4

                        StyledText {
                            text: root.nextTime !== "" ? (root.isAr ? ("متبقي على " + root.getPrayerName(root.nextName)) : (root.nextName + " in")) : "—"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: root.nextTime !== "" ? root.formatCountdown(root.nextTotalSeconds) : "—"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: root.isUrgent ? root.accentColor : Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter

                            Behavior on color {
                                ColorAnimation { duration: 400 }
                            }
                        }

                        StyledText {
                            text: root.nextTime !== "" ? ((root.isAr ? "في تمام " : "at ") + root.formatTime(root.nextTime)) : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Prayer times list
                Repeater {
                    model: [
                        { label: "Imsak", time: root.imsak, icon: "moon_stars" },
                        { label: "Fajr", time: root.fajr, icon: "bedtime" },
                        { label: "Sunrise", time: root.sunrise, icon: "wb_twilight" },
                        { label: "Dhuhr", time: root.dhuhr, icon: "wb_sunny" },
                        { label: "Asr", time: root.asr, icon: "light_mode" },
                        { label: "Maghrib", time: root.maghrib, icon: "wb_twilight" },
                        { label: "Isha", time: root.isha, icon: "bedtime" }
                    ]

                    delegate: Item {
                        width: parent.width
                        height: 36

                        readonly property bool isNext: modelData.label === root.nextName
                        readonly property bool isCurr: modelData.label === root.currName

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: height / 2
                            color: isNext ? root.accentBg : (isCurr ? root.subtleBg : "transparent")
                            border.color: isNext ? root.accentColor : "transparent"
                            border.width: isNext ? 1 : 0
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            Row {
                                spacing: Theme.spacingS
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    name: modelData.icon
                                    size: Theme.iconSize
                                    color: isNext ? root.accentColor : (isCurr ? Theme.surfaceText : Theme.surfaceVariantText)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: root.getPrayerName(modelData.label)
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: (isNext || isCurr) ? Font.Bold : Font.Normal
                                    color: isNext ? root.accentColor : (isCurr ? Theme.surfaceText : Theme.surfaceVariantText)
                                    width: 75
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            StyledText {
                                text: root.formatTime(modelData.time)
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: (isNext || isCurr) ? Font.Bold : Font.Normal
                                color: isNext ? root.accentColor : (isCurr ? Theme.surfaceText : Theme.surfaceVariantText)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                width: 70
                            }
                        }
                    }
                }
            }
        }
    }
}
