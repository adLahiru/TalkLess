#include "soundboardService.h"

#include <QFileInfo>

SoundboardService::SoundboardService(QObject* parent)
  : QObject(parent)
{
    // 1) Load index (might not exist)
    m_state = m_repo.loadIndex();

    // 2) First launch: no boards -> create one
    if (m_state.soundboards.isEmpty()) {
        int id = m_repo.createBoard("Default"); // creates board_1.json and updates index
        m_state = m_repo.loadIndex();
        m_state.activeBoardId = id;
        m_repo.saveIndex(m_state);
    }

    // 3) Activate the last active board
    int idToActivate = m_state.activeBoardId;
    if (idToActivate < 0 && !m_state.soundboards.isEmpty())
        idToActivate = m_state.soundboards.first().id;

    if (idToActivate >= 0)
        activate(idToActivate);

    // 4) Notify UI
    emit boardsChanged();
    emit activeBoardChanged();
    emit activeClipsChanged();
}


void SoundboardService::reloadIndex()
{
    m_state = m_repo.loadIndex();
    emit boardsChanged();
    emit settingsChanged();
}

int SoundboardService::activeBoardId() const
{
    return m_active ? m_active->id : -1;
}

QString SoundboardService::activeBoardName() const
{
    return m_active ? m_active->name : QString();
}

void SoundboardService::setMasterGainDb(double db)
{
    m_state.settings.masterGainDb = db;
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}

void SoundboardService::setMicGainDb(double db)
{
    m_state.settings.micGainDb = db;
    m_repo.saveIndex(m_state);
    emit settingsChanged();
}

bool SoundboardService::activate(int boardId)
{
    // Save current active board before switching
    if (m_active) {
        m_repo.saveBoard(*m_active);
    }

    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return false;

    m_active = *loaded;
    rebuildHotkeyIndex();

    // Update index activeBoardId
    m_state.activeBoardId = boardId;
    m_repo.saveIndex(m_state);

    emit activeBoardChanged();
    emit activeClipsChanged();
    emit boardsChanged();
    return true;
}

bool SoundboardService::saveActive()
{
    if (!m_active) return false;

    const bool ok = m_repo.saveBoard(*m_active);
    if (ok) {
        // reload index because clipCount/name might update
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

QString SoundboardService::normalizeHotkey(const QString& hotkey)
{
    return hotkey.trimmed();
}

void SoundboardService::rebuildHotkeyIndex()
{
    m_hotkeyToClipId.clear();
    if (!m_active) return;

    for (const auto& c : m_active->clips) {
        const QString hk = normalizeHotkey(c.hotkey);
        if (!hk.isEmpty()) {
            m_hotkeyToClipId[hk] = c.id;
        }
    }
}

int SoundboardService::findActiveClipIdByHotkey(const QString& hotkey) const
{
    const QString hk = normalizeHotkey(hotkey);
    if (hk.isEmpty()) return -1;
    return m_hotkeyToClipId.value(hk, -1);
}

Clip* SoundboardService::findActiveClipById(int clipId)
{
    if (!m_active) return nullptr;
    for (auto& c : m_active->clips) {
        if (c.id == clipId) return &c;
    }
    return nullptr;
}

bool SoundboardService::setClipPlaying(int clipId, bool playing)
{
    Clip* c = findActiveClipById(clipId);
    if (!c) return false;

    c->isPlaying = playing;
    c->locked = playing;
    emit activeClipsChanged();
    return true;
}

bool SoundboardService::addClipToBoard(int boardId, const Clip& draft)
{
    if (draft.filePath.trimmed().isEmpty()) return false;

    // if adding to active board (in memory)
    if (m_active && m_active->id == boardId) {
        Clip c = draft;

        // default title if empty
        if (c.title.trimmed().isEmpty()) {
            c.title = QFileInfo(c.filePath).baseName();
        } else {
            c.title = c.title.trimmed();
        }

        // runtime defaults
        c.isPlaying = false;
        c.locked = false;

        // generate clip id (simple)
        int maxId = 0;
        for (const auto& x : m_active->clips) maxId = std::max(maxId, x.id);
        c.id = maxId + 1;

        m_active->clips.push_back(c);
        rebuildHotkeyIndex();

        emit activeClipsChanged();
        return saveActive();
    }

    // inactive board: load -> modify -> save
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return false;

    Soundboard b = *loaded;

    Clip c = draft;
    if (c.title.trimmed().isEmpty()) c.title = QFileInfo(c.filePath).baseName();
    c.isPlaying = false;
    c.locked = false;

    int maxId = 0;
    for (const auto& x : b.clips) maxId = std::max(maxId, x.id);
    c.id = maxId + 1;

    b.clips.push_back(c);

    const bool ok = m_repo.saveBoard(b);
    if (ok) {
        m_state = m_repo.loadIndex();
        emit boardsChanged();
    }
    return ok;
}

bool SoundboardService::updateClipInBoard(int boardId, int clipId, const Clip& updatedClip)
{
    // active board update (enforce locked)
    if (m_active && m_active->id == boardId) {
        for (auto& c : m_active->clips) {
            if (c.id != clipId) continue;
            if (c.locked) return false;

            Clip n = updatedClip;
            n.id = clipId;

            if (n.title.trimmed().isEmpty()) n.title = QFileInfo(n.filePath).baseName();
            n.isPlaying = c.isPlaying;
            n.locked = c.locked;

            c = n;

            rebuildHotkeyIndex();
            emit activeClipsChanged();
            return saveActive();
        }
        return false;
    }

    // inactive board update
    auto loaded = m_repo.loadBoard(boardId);
    if (!loaded) return false;

    Soundboard b = *loaded;
    for (auto& c : b.clips) {
        if (c.id != clipId) continue;

        Clip n = updatedClip;
        n.id = clipId;
        if (n.title.trimmed().isEmpty()) n.title = QFileInfo(n.filePath).baseName();
        n.isPlaying = false;
        n.locked = false;

        c = n;

        const bool ok = m_repo.saveBoard(b);
        if (ok) {
            m_state = m_repo.loadIndex();
            emit boardsChanged();
        }
        return ok;
    }
    return false;
}
