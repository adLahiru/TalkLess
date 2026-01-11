#include "storageRepository.h"

#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
#include <algorithm>
#include <QCoreApplication>

// ------------------ JSON helpers ------------------

static QJsonObject settingsToJson(const AppSettings& s)
{
    QJsonObject o;
    o["masterGainDb"] = s.masterGainDb;
    o["micGainDb"] = s.micGainDb;
    o["selectedPlaybackDeviceId"] = s.selectedPlaybackDeviceId;
    o["selectedCaptureDeviceId"] = s.selectedCaptureDeviceId;
    o["selectedMonitorDeviceId"] = s.selectedMonitorDeviceId;
    o["theme"] = s.theme;
    o["accentColor"] = s.accentColor;
    o["slotSize"] = s.slotSize;
    o["language"] = s.language;
    o["hotkeyMode"] = s.hotkeyMode;
    o["micEnabled"] = s.micEnabled;
    o["micPassthroughEnabled"] = s.micPassthroughEnabled;
    o["micSoundboardBalance"] = s.micSoundboardBalance;
    return o;
}

static AppSettings settingsFromJson(const QJsonObject& o)
{
    AppSettings s;
    s.masterGainDb = o.value("masterGainDb").toDouble(0.0);
    s.micGainDb = o.value("micGainDb").toDouble(0.0);
    s.selectedPlaybackDeviceId = o.value("selectedPlaybackDeviceId").toString();
    s.selectedCaptureDeviceId = o.value("selectedCaptureDeviceId").toString();
    s.selectedMonitorDeviceId = o.value("selectedMonitorDeviceId").toString();
    s.theme = o.value("theme").toString("Dark");
    s.accentColor = o.value("accentColor").toString("#3B82F6");
    s.slotSize = o.value("slotSize").toString("Standard");
    s.language = o.value("language").toString("English");
    s.hotkeyMode = o.value("hotkeyMode").toString("ActiveBoardOnly");
    s.micEnabled = o.value("micEnabled").toBool(true);
    s.micPassthroughEnabled = o.value("micPassthroughEnabled").toBool(true);
    s.micSoundboardBalance = (float)o.value("micSoundboardBalance").toDouble(0.5);
    return s;
}

static QJsonObject soundboardInfoToJson(const SoundboardInfo& i)
{
    QJsonObject o;
    o["id"] = i.id;
    o["name"] = i.name;
    o["hotkey"] = i.hotkey;
    o["clipCount"] = i.clipCount;
    return o;
}

static SoundboardInfo soundboardInfoFromJson(const QJsonObject& o)
{
    SoundboardInfo i;
    i.id = o.value("id").toInt(-1);
    i.name = o.value("name").toString();
    i.hotkey = o.value("hotkey").toString();
    i.clipCount = o.value("clipCount").toInt(0);
    return i;
}

static QJsonObject clipToJson(const Clip& c)
{
    QJsonObject o;
    o["id"] = c.id;
    o["filePath"] = c.filePath;
    o["imgPath"] = c.imgPath;
    o["hotkey"] = c.hotkey;

    QJsonArray tags;
    for (const auto& t : c.tags) tags.append(t);
    o["tags"] = tags;

    o["trimStartMs"] = static_cast<qint64>(c.trimStartMs);
    o["trimEndMs"] = static_cast<qint64>(c.trimEndMs);

    // Per-clip audio settings
    o["volume"] = c.volume;
    o["speed"] = c.speed;

    o["title"] = c.title;
    o["isRepeat"] = c.isRepeat;
    o["reproductionMode"] = c.reproductionMode;
    
    // Playback behavior options
    o["stopOtherSounds"] = c.stopOtherSounds;
    o["muteOtherSounds"] = c.muteOtherSounds;
    o["muteMicDuringPlayback"] = c.muteMicDuringPlayback;

    // runtime-only (do not save): isPlaying, locked
    return o;
}

static Clip clipFromJson(const QJsonObject& o)
{
    Clip c;
    c.id = o.value("id").toInt(-1);
    c.filePath = o.value("filePath").toString();
    c.imgPath = o.value("imgPath").toString();
    c.hotkey = o.value("hotkey").toString();

    const auto tagsArr = o.value("tags").toArray();
    for (const auto& v : tagsArr) c.tags.push_back(v.toString());

    c.trimStartMs = o.value("trimStartMs").toVariant().toLongLong();
    c.trimEndMs = o.value("trimEndMs").toVariant().toLongLong();

    // Per-clip audio settings (with defaults)
    c.volume = o.value("volume").toInt(100);
    c.speed = o.value("speed").toDouble(1.0);

    c.title = o.value("title").toString();
    c.isRepeat = o.value("isRepeat").toBool(false);
    c.reproductionMode = o.value("reproductionMode").toInt(1); // Default to Play/Pause
    
    // Playback behavior options
    c.stopOtherSounds = o.value("stopOtherSounds").toBool(false);
    c.muteOtherSounds = o.value("muteOtherSounds").toBool(false);
    c.muteMicDuringPlayback = o.value("muteMicDuringPlayback").toBool(false);

    // runtime defaults
    c.isPlaying = false;
    c.locked = false;
    return c;
}

static QJsonObject soundboardToJson(const Soundboard& b)
{
    QJsonObject root;
    root["id"] = b.id;
    root["name"] = b.name;
    root["hotkey"] = b.hotkey;

    QJsonArray clipsArr;
    for (const auto& c : b.clips) clipsArr.append(clipToJson(c));
    root["clips"] = clipsArr;

    return root;
}

static Soundboard soundboardFromJson(const QJsonObject& root)
{
    Soundboard b;
    b.id = root.value("id").toInt(-1);
    b.name = root.value("name").toString();
    b.hotkey = root.value("hotkey").toString();

    const auto clipsArr = root.value("clips").toArray();
    for (const auto& v : clipsArr) b.clips.push_back(clipFromJson(v.toObject()));

    return b;
}

// ------------------ StorageRepository ------------------

StorageRepository::StorageRepository()
{
    ensureDirs();
}

QString StorageRepository::baseDir() const
{
    QString root = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);

    // If Qt returns empty (can happen if app name not set early)
    if (root.isEmpty()) {
        root = QDir::homePath() + "/.TalkLess"; // fallback
    }

    // Put your data inside a TalkLess folder (clean + predictable)
    // This also avoids weird paths when org/app names change.
    QDir dir(root);
    dir.mkpath(".");  // ensure root exists

    // Final folder
    const QString finalPath = dir.filePath("soundboards");
    QDir(finalPath).mkpath(".");
    qDebug() << "AppDataLocation =" << QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    qDebug() << "Storage baseDir =" << finalPath;
    return QDir::cleanPath(finalPath);
}

QString StorageRepository::indexPath() const
{
    return QDir(baseDir()).filePath("index.json");
}

QString StorageRepository::boardsDir() const
{
    return QDir(baseDir()).filePath("boards");
}

QString StorageRepository::boardPath(int boardId) const
{
    return QDir(boardsDir()).filePath(QString("board_%1.json").arg(boardId));
}

bool StorageRepository::ensureDirs() const
{
    QDir d(baseDir());
    if (!d.exists() && !d.mkpath(".")) return false;

    QDir b(boardsDir());
    if (!b.exists() && !b.mkpath(".")) return false;

    return true;
}

int StorageRepository::nextBoardId(const QVector<SoundboardInfo>& items) const
{
    int maxId = 0;
    for (const auto& i : items) maxId = std::max(maxId, i.id);
    return maxId + 1;
}

AppState StorageRepository::loadIndex() const
{
    AppState state;
    ensureDirs();

    QFile f(indexPath());
    if (!f.exists()) {
        // No index yet -> defaults
        return state;
    }
    if (!f.open(QIODevice::ReadOnly)) {
        return state;
    }

    const auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) return state;

    const auto root = doc.object();
    state.version = root.value("version").toInt(1);
    
    // Load active board IDs (supports both old single activeBoardId and new activeBoardIds array)
    if (root.contains("activeBoardIds") && root.value("activeBoardIds").isArray()) {
        const auto idsArr = root.value("activeBoardIds").toArray();
        for (const auto& v : idsArr) {
            int id = v.toInt(-1);
            if (id >= 0) state.activeBoardIds.insert(id);
        }
    } else if (root.contains("activeBoardId")) {
        // Migrate from old single activeBoardId format
        int id = root.value("activeBoardId").toInt(-1);
        if (id >= 0) state.activeBoardIds.insert(id);
    }

    if (root.contains("settings") && root.value("settings").isObject()) {
        state.settings = settingsFromJson(root.value("settings").toObject());
    }

    const auto boardsArr = root.value("soundboards").toArray();
    for (const auto& v : boardsArr) {
        const auto info = soundboardInfoFromJson(v.toObject());
        if (info.id >= 0) state.soundboards.push_back(info);
    }

    return state;
}

bool StorageRepository::saveIndex(const AppState& state) const
{
    ensureDirs();

    QJsonObject root;
    root["version"] = state.version;
    
    // Save active board IDs as array
    QJsonArray activeBoardIdsArr;
    for (int id : state.activeBoardIds) {
        activeBoardIdsArr.append(id);
    }
    root["activeBoardIds"] = activeBoardIdsArr;
    
    root["settings"] = settingsToJson(state.settings);

    QJsonArray boardsArr;
    for (const auto& b : state.soundboards) boardsArr.append(soundboardInfoToJson(b));
    root["soundboards"] = boardsArr;

    QFile f(indexPath());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    return true;
}

QVector<SoundboardInfo> StorageRepository::listBoards() const
{
    return loadIndex().soundboards;
}

std::optional<Soundboard> StorageRepository::loadBoard(int boardId) const
{
    ensureDirs();

    QFile f(boardPath(boardId));
    if (!f.exists()) return std::nullopt;
    if (!f.open(QIODevice::ReadOnly)) return std::nullopt;

    const auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) return std::nullopt;

    return soundboardFromJson(doc.object());
}

bool StorageRepository::saveBoard(const Soundboard& board)
{
    ensureDirs();

    // 1) Save board_<id>.json
    QFile f(boardPath(board.id));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    f.write(QJsonDocument(soundboardToJson(board)).toJson(QJsonDocument::Indented));

    // 2) Update index.json: name + clipCount for this board
    AppState state = loadIndex();

    bool found = false;
    for (auto& info : state.soundboards) {
        if (info.id == board.id) {
            info.name = board.name;
            info.hotkey = board.hotkey;
            info.clipCount = board.clips.size();
            found = true;
            break;
        }
    }
    if (!found) {
        SoundboardInfo info;
        info.id = board.id;
        info.name = board.name;
        info.clipCount = board.clips.size();
        state.soundboards.push_back(info);
    }

    return saveIndex(state);
}

int StorageRepository::createBoard(const QString& name)
{
    AppState state = loadIndex();
    const int id = nextBoardId(state.soundboards);

    Soundboard b;
    b.id = id;
    b.name = name;

    // Save board file + index update
    saveBoard(b);

    // Ensure at least one board is active if none exists
    state = loadIndex();
    if (state.activeBoardIds.isEmpty()) {
        state.activeBoardIds.insert(id);
        saveIndex(state);
    }

    return id;
}

bool StorageRepository::deleteBoard(int boardId)
{
    ensureDirs();

    QFile::remove(boardPath(boardId));

    AppState state = loadIndex();
    for (int i = 0; i < state.soundboards.size(); ++i) {
        if (state.soundboards[i].id == boardId) {
            state.soundboards.removeAt(i);
            break;
        }
    }
    
    // Remove from active boards if present
    state.activeBoardIds.remove(boardId);

    return saveIndex(state);
}
