#ifndef APICLIENT_H
#define APICLIENT_H

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QQmlEngine>
#include <QSettings>
#include <QString>

class ApiClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY isLoggedInChanged)
    Q_PROPERTY(bool isGuest READ isGuest NOTIFY isGuestChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString currentUserFirstName READ currentUserFirstName NOTIFY currentUserChanged)
    Q_PROPERTY(QString currentUserLastName READ currentUserLastName NOTIFY currentUserChanged)
    Q_PROPERTY(QString currentUserEmail READ currentUserEmail NOTIFY currentUserChanged)
    Q_PROPERTY(QString displayName READ displayName NOTIFY currentUserChanged)

public:
    explicit ApiClient(QObject* parent = nullptr);

    // Property getters
    bool isLoading() const { return m_isLoading; }
    bool isLoggedIn() const { return m_isLoggedIn; }
    bool isGuest() const { return m_isGuest; }
    QString errorMessage() const { return m_errorMessage; }
    QString currentUserFirstName() const { return m_firstName; }
    QString currentUserLastName() const { return m_lastName; }
    QString currentUserEmail() const { return m_email; }
    QString displayName() const { return m_isGuest ? "Guest" : m_firstName; }

    // API Methods (Q_INVOKABLE for QML access)
    Q_INVOKABLE void signup(const QString& email, const QString& password, const QString& firstName,
                            const QString& lastName, const QString& phoneNumber = QString());
    Q_INVOKABLE void login(const QString& email, const QString& password, bool rememberMe = false);
    Q_INVOKABLE void loginAsGuest();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void checkSavedSession();

signals:
    void isLoadingChanged();
    void isLoggedInChanged();
    void isGuestChanged();
    void errorMessageChanged();
    void currentUserChanged();

    // Auth result signals
    void signupSuccess();
    void signupError(const QString& message);
    void loginSuccess();
    void loginError(const QString& message);
    void logoutSuccess();
    void sessionRestored();
    void sessionInvalid();

private slots:
    void onNetworkReply(QNetworkReply* reply);

private:
    QNetworkAccessManager* m_networkManager;
    QString m_baseUrl;
    QString m_authToken;

    // State
    bool m_isLoading = false;
    bool m_isLoggedIn = false;
    bool m_isGuest = false;
    bool m_rememberMe = false;
    QString m_errorMessage;

    // User data
    QString m_firstName;
    QString m_lastName;
    QString m_email;
    QString m_userId;

    // Helper methods
    void sendPostRequest(const QString& endpoint, const QJsonObject& data, const QString& requestType);
    void sendGetRequest(const QString& endpoint, const QString& requestType);
    QNetworkRequest createRequest(const QString& endpoint, bool requiresAuth = false);

    // Token persistence
    void saveAuthToken(const QString& token);
    QString loadAuthToken();
    void clearAuthToken();

    // User data persistence
    void saveUserData();
    void loadUserData();
    void clearUserData();

    void setLoading(bool loading);
    void setError(const QString& error);
    void setLoggedIn(bool loggedIn, bool isGuest = false);
    void setUserData(const QJsonObject& userData);
};

#endif // APICLIENT_H
