export interface Customer {
  id: number;
  name: string;
  email: string;
  phone: string | null;
  address: string | null;
  registrationDate: string;
}

export interface CustomerRequest {
  name: string;
  email: string;
  phone: string | null;
  address: string | null;
}
