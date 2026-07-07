package SDKMethods.core;

/**
 * EPC Tag Model - Represents a scanned RFID tag
 */
public class EPC {
    private String id;
    private String epc;
    private String count;
    private String rssi;
    private boolean isFind;
    private String tid;      // TID (hex) captured during inventory (combined mode)
    private String user;     // USER memory (hex) captured during inventory (combined mode)
    private boolean validTid;

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getEpc() { return epc; }
    public void setEpc(String epc) { this.epc = epc; }

    public String getCount() { return count; }
    public void setCount(String count) { this.count = count; }

    public String getRssi() { return rssi; }
    public void setRssi(String rssi) { this.rssi = rssi; }

    public boolean isFind() { return isFind; }
    public void setFind(boolean find) { isFind = find; }

    public String getTid() { return tid; }
    public void setTid(String tid) { this.tid = tid; }

    public String getUser() { return user; }
    public void setUser(String user) { this.user = user; }

    public boolean isValidTid() { return validTid; }
    public void setValidTid(boolean validTid) { this.validTid = validTid; }

    @Override
    public String toString() {
        return "EPC [id=" + id + ", epc=" + epc + ", count=" + count + "]";
    }
}

